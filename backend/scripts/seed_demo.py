# Fills the database with a fictitious association living around today: invented
# people, opening hours, bookings, published calendars, notes and notices, on the
# catalogues (disciplines, subjects, programmes, schools) of a JSON export.
#
#     DEMO_PASSWORD=... python -m scripts.seed_demo --catalog catalog.json \
#         --keep nicolo.calore
#
# Every table is emptied first: only the accounts named with --keep stay, with
# their roles and memberships. The one demo account, demo.utente, gets
# DEMO_PASSWORD; every other account gets one nobody knows. Run it again every
# few weeks: the calendar follows the day it runs on.

import argparse
import asyncio
import json
import os
import random
import secrets
import sys
import unicodedata
from collections import defaultdict
from collections.abc import Sequence
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta
from decimal import Decimal
from typing import Final

from sqlalchemy import func, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.booking_close import closes_at, has_closed
from app.core.booking_window import compute_available_window, now_in_rome
from app.core.holidays import holidays_for_year
from app.core.school_year import school_year_start
from app.core.security import hash_password
from app.core.time_band import TimeBandEnum, band_of
from app.core.time_step import minutes_between
from app.db.base import Base
from app.db.session import AsyncSessionLocal
from app.models.account import Account, AccountStatusEnum
from app.models.administrator import Administrator, AdministratorRoleEnum
from app.models.administrator_note import AdministratorNote
from app.models.association_subject import AssociationSubject
from app.models.availability import Availability
from app.models.booking import Booking, BookingTagEnum
from app.models.booking_preferred_teacher import BookingPreferredTeacher
from app.models.calendar_activity import CalendarActivity
from app.models.calendar_publication import CalendarPublication
from app.models.course import Course
from app.models.course_participant import CourseParticipant
from app.models.early_exit_schedule import EarlyExitSchedule
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.lesson_discipline import LessonDiscipline
from app.models.member import Member, PaymentMethodEnum
from app.models.membership import Membership
from app.models.methodological_note import MethodologicalNote
from app.models.ministry_association_subject import MinistryAssociationSubject
from app.models.ministry_subject import MinistrySubject
from app.models.notice import Notice, NoticeFile, NoticePin, NoticeRoleEnum
from app.models.notification import Notification
from app.models.opening_day import OpeningDay
from app.models.parent import Parent
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import (
    _TAX_CODE_CHECK_CHARACTERS,
    _TAX_CODE_EVEN_POSITION_VALUES,
    _TAX_CODE_ODD_POSITION_VALUES,
    BORN_ABROAD_PROVINCE,
    GenderEnum,
    Person,
)
from app.models.presence import Presence
from app.models.psychological_support import PsychologicalSupport
from app.models.psychologist import Psychologist
from app.models.report import ReportKindEnum
from app.models.room import Room
from app.models.room_supervision import RoomSupervision
from app.models.school import School
from app.models.school_enrollment import SchoolEnrollment
from app.models.school_study_program import SchoolStudyProgram
from app.models.service import Service
from app.models.staff import CollaborationTypeEnum, Staff
from app.models.student import CertificationTypeEnum, HomeworkTariffEnum, Student
from app.models.student_not_preferred_teacher import StudentNotPreferredTeacher
from app.models.study_program import (
    EducationLevelEnum,
    HighSchoolTrackEnum,
    StudyProgram,
)
from app.models.study_program_subject import StudyProgramSubject
from app.models.subject_requested import SubjectRequested
from app.models.teacher import Teacher
from app.models.teacher_note import TeacherNote
from app.models.teacher_room_assignment import MIDNIGHT, TeacherRoomAssignment
from app.models.teacher_service import TeacherService
from app.models.teaching_competence import TeachingCompetence
from app.models.technical_note import TechnicalNote
from app.models.weekly_template import WeeklyTemplate
from app.services.administrator_note_notifications import (
    announce_administrator_note,
)
from app.services.calendar_published import announce_publication
from app.services.notice_notifications import announce_notice
from app.services.reports import record_report, resolve_report
from app.services.room_occupancy import rooms_left_open, teachers_adrift
from app.services.teacher_note_notifications import announce_teacher_note
from app.services.teacher_occupancy import MAX_CONCURRENT_STUDENTS

_PASSWORD_VARIABLE: Final[str] = "DEMO_PASSWORD"

# Resend's test inbox: accepted and counted, never delivered to anyone.
_EMAIL: Final[str] = "delivered+{slug}@resend.dev"

_PRESENCE: Final[str] = "presence"
_ONLINE: Final[str] = "online"

# A person's own rows kept across the wipe, parents of a row before its children.
_KEPT_ROWS: Final[tuple[tuple[str, str], ...]] = (
    ("people", "tax_code"),
    ("accounts", "tax_code"),
    ("members", "tax_code"),
    ("memberships", "member_tax_code"),
    ("staff", "tax_code"),
    ("administrators", "tax_code"),
    ("teachers", "tax_code"),
    ("psychologists", "tax_code"),
    ("parents", "tax_code"),
    ("refresh_tokens", "account_tax_code"),
    ("known_devices", "account_tax_code"),
    ("push_devices", "account_tax_code"),
    ("seen_tours", "account_tax_code"),
    ("muted_notification_kinds", "account_tax_code"),
)

_MONTH_LETTERS: Final[str] = "ABCDEHLMPRST"
_VOWELS: Final[str] = "AEIOU"

_WEEKDAYS: Final[tuple[str, ...]] = (
    "lunedì",
    "martedì",
    "mercoledì",
    "giovedì",
    "venerdì",
    "sabato",
    "domenica",
)
_MONTHS: Final[tuple[str, ...]] = (
    "gennaio",
    "febbraio",
    "marzo",
    "aprile",
    "maggio",
    "giugno",
    "luglio",
    "agosto",
    "settembre",
    "ottobre",
    "novembre",
    "dicembre",
)

# Province, cadastral code and postal code of every town named below.
_TOWNS: Final[dict[str, tuple[str, str, str]]] = {
    "Thiene": ("VI", "L157", "36016"),
    "Zanè": ("VI", "M145", "36010"),
    "Marano Vicentino": ("VI", "E912", "36035"),
    "Sarcedo": ("VI", "I425", "36030"),
    "Schio": ("VI", "I531", "36015"),
    "Carrè": ("VI", "B835", "36010"),
    "Breganze": ("VI", "B132", "36042"),
    "Villaverla": ("VI", "L952", "36030"),
    "Santorso": ("VI", "I353", "36014"),
    "Vicenza": ("VI", "L840", "36100"),
    "Bassano del Grappa": ("VI", "A703", "36061"),
    "Padova": ("PD", "G224", "35121"),
    "Verona": ("VR", "L781", "37121"),
    "Napoli": ("NA", "F839", "80121"),
}

_COUNTRIES: Final[dict[str, str]] = {
    "Romania": "Z129",
    "Marocco": "Z330",
    "Albania": "Z100",
}

_STREETS: Final[tuple[tuple[str, str], ...]] = (
    ("Via", "Roma"),
    ("Via", "Garibaldi"),
    ("Via", "Monte Grappa"),
    ("Via", "dei Ciliegi"),
    ("Via", "San Gaetano"),
    ("Via", "Trieste"),
    ("Via", "Montello"),
    ("Via", "Marconi"),
    ("Via", "IV Novembre"),
    ("Via", "Dante Alighieri"),
    ("Via", "Fogazzaro"),
    ("Viale", "Europa"),
    ("Via", "Santa Maria"),
    ("Contrà", "San Rocco"),
    ("Via", "Valbella"),
    ("Via", "Pasubio"),
    ("Via", "Ortigara"),
    ("Via", "Carducci"),
    ("Via", "Kennedy"),
    ("Piazza", "Chilesotti"),
)

_PRIMARY: Final = EducationLevelEnum.PRIMARY_SCHOOL
_MIDDLE: Final = EducationLevelEnum.MIDDLE_SCHOOL
_HIGH: Final = EducationLevelEnum.HIGH_SCHOOL
_BIENNIO: Final = HighSchoolTrackEnum.BIENNIO
_TRIENNIO: Final = HighSchoolTrackEnum.TRIENNIO

# The catalogue's programmes the pupils attend: level, sector, name, track.
# Primary and middle school are found by the start of their name.
_PROGRAM_KEYS: Final[dict[str, tuple]] = {
    "primaria": (_PRIMARY, None, "Scuola primaria", None),
    "media": (_MIDDLE, None, "Scuola secondaria di I grado", None),
    "sci_b": (_HIGH, "Liceo", "Scientifico", _BIENNIO),
    "sci_t": (_HIGH, "Liceo", "Scientifico", _TRIENNIO),
    "cla_b": (_HIGH, "Liceo", "Classico", _BIENNIO),
    "cla_t": (_HIGH, "Liceo", "Classico", _TRIENNIO),
    "lin_b": (_HIGH, "Liceo", "Linguistico", _BIENNIO),
    "lin_t": (_HIGH, "Liceo", "Linguistico", _TRIENNIO),
    "su_b": (_HIGH, "Liceo", "Scienze umane", _BIENNIO),
    "su_t": (_HIGH, "Liceo", "Scienze umane", _TRIENNIO),
    "afm_b": (
        _HIGH,
        "Istituto tecnico economico",
        "Amministrazione, finanza e marketing",
        _BIENNIO,
    ),
    "afm_t": (
        _HIGH,
        "Istituto tecnico economico",
        "Amministrazione, finanza e marketing",
        _TRIENNIO,
    ),
    "inf_b": (
        _HIGH,
        "Istituto tecnico tecnologico",
        "Informatica e telecomunicazioni",
        _BIENNIO,
    ),
    "inf_t": (
        _HIGH,
        "Istituto tecnico tecnologico",
        "Informatica e telecomunicazioni - Informatica",
        _TRIENNIO,
    ),
    "eno_b": (
        _HIGH,
        "Istituto professionale",
        "Enogastronomia e ospitalità alberghiera",
        _BIENNIO,
    ),
}

# Where a first year comes from: the last year of the programme before.
_PREVIOUS_PROGRAM: Final[dict[str, str]] = {
    "media": "primaria",
    "sci_b": "media",
    "cla_b": "media",
    "lin_b": "media",
    "su_b": "media",
    "afm_b": "media",
    "inf_b": "media",
    "eno_b": "media",
    "sci_t": "sci_b",
    "cla_t": "cla_b",
    "lin_t": "lin_b",
    "su_t": "su_b",
    "afm_t": "afm_b",
    "inf_t": "inf_b",
}

# How often families ask for a ministry subject, by a piece of its name; the
# first match wins and zero leaves the subject out.
_NEED_WEIGHTS: Final[tuple[tuple[str, int], ...]] = (
    ("motorie", 0),
    ("Educazione", 0),
    ("Religione", 0),
    ("Musica", 0),
    ("Arte e immagine", 0),
    ("Laboratorio", 0),
    ("Matematica", 5),
    ("latina", 3),
    ("greca", 3),
    ("Economia aziendale", 3),
    ("Inglese", 3),
    ("Italiano", 3),
    ("italiana", 3),
    ("Fisica", 2),
    ("Informatica", 2),
    ("Tecnologie dell'informazione", 2),
    ("Scienze umane", 2),
    ("Francese", 1),
    ("Tedesco", 1),
    ("Spagnolo", 1),
    ("Scienze", 1),
    ("Filosofia", 1),
    ("Diritto", 1),
    ("Storia", 1),
    ("Geografia", 1),
)

_SERVICES: Final[tuple[tuple[str, str], ...]] = (
    ("Metodo di studio", "Come organizzare il diario, i compiti e lo studio a casa."),
    ("Orientamento scolastico", "Supporto nella scelta della scuola superiore."),
    (
        "Preparazione agli esami",
        "Ripasso e simulazioni per l'esame di terza media e la maturità.",
    ),
)

_ROOMS: Final[tuple[tuple[str, int, str], ...]] = (
    ("Aula Galileo", 6, "Primo piano, con lavagna e proiettore."),
    ("Aula Montessori", 6, "Piano terra, accanto all'ingresso."),
    ("Aula Rodari", 4, "Per i più piccoli: tavoli bassi e libri illustrati."),
    ("Biblioteca", 8, "Silenziosa, con i libri di testo in prestito."),
)

_COURSES: Final[tuple[tuple[str, str, str], ...]] = (
    (
        "Laboratorio di scacchi",
        "Il giovedì sera, per adulti e ragazzi.",
        "30 euro al trimestre",
    ),
    ("Corso di fotografia", "Uscite di gruppo il sabato mattina.", "45 euro al mese"),
)

# Weekday (1 Monday), mode, opening, closing.
_WEEKLY_HOURS: Final[tuple[tuple[int, str, str, str], ...]] = (
    *((weekday, _PRESENCE, "14:30", "18:30") for weekday in range(1, 6)),
    *((weekday, _ONLINE, "14:30", "18:30") for weekday in range(1, 6)),
    *((weekday, _ONLINE, "20:00", "22:00") for weekday in (1, 3, 4)),
    (6, _PRESENCE, "09:00", "12:30"),
    (6, _ONLINE, "09:00", "12:30"),
)

_TOPICS: Final[dict[str, tuple[str, ...]]] = {
    "Grammatica italiana": ("Analisi logica", "Analisi del periodo", "Il verbo"),
    "Antologia": ("Il racconto giallo", "Il testo poetico"),
    "Epica": ("L'Iliade", "L'Odissea", "L'Eneide"),
    "Letteratura italiana": ("Dante, Inferno", "Petrarca", "Leopardi", "Il Verismo"),
    "Produzione scritta": ("Tema argomentativo", "Riassunto", "Testo descrittivo"),
    "Lettura e comprensione": ("Comprensione del testo", "Lettura ad alta voce"),
    "Grammatica latina": (
        "Ablativo assoluto",
        "Proposizioni infinitive",
        "Terza declinazione",
    ),
    "Cultura latina": ("Versione da Cesare", "Versione da Cicerone"),
    "Letteratura latina": ("Catullo", "Virgilio, Eneide"),
    "Grammatica greca": ("Verbi in -mi", "Aoristo", "Prima declinazione"),
    "Cultura greca": ("Versione da Senofonte", "Versione da Lisia"),
    "Letteratura greca": ("Omero", "La tragedia"),
    "Storia": ("La Rivoluzione francese", "Il Risorgimento", "L'Impero romano"),
    "Geografia": ("Le regioni italiane", "L'Europa fisica", "I climi"),
    "Filosofia": ("I presocratici", "Platone", "Kant"),
    "Storia dell'arte": ("Il Rinascimento", "L'arte gotica"),
    "Diritto": ("La Costituzione", "Le fonti del diritto", "Il contratto"),
    "Economia politica": ("Domanda e offerta", "Il mercato"),
    "Psicologia": ("Piaget", "La memoria", "L'apprendimento"),
    "Pedagogia": ("Montessori", "L'educazione nel Novecento"),
    "Sociologia": ("La socializzazione", "Le istituzioni sociali"),
    "Grammatica inglese": ("Present perfect", "Conditionals", "Passive voice"),
    "Letteratura inglese": ("Il Romanticismo", "Shakespeare, Macbeth"),
    "Microlingua inglese": ("Business English", "Reading comprehension"),
    "Grammatica francese": ("Passé composé", "Les articles partitifs"),
    "Grammatica tedesca": ("Akkusativ und Dativ", "Perfekt"),
    "Grammatica spagnola": ("Pretérito indefinido", "Ser y estar"),
    "Aritmetica": ("Frazioni", "MCD e mcm", "Potenze", "Proporzioni"),
    "Algebra": ("Equazioni di secondo grado", "Disequazioni fratte", "Sistemi lineari"),
    "Geometria": ("Teorema di Pitagora", "Circonferenza e cerchio", "La retta"),
    "Analisi matematica": ("Limiti", "Derivate", "Studio di funzione"),
    "Probabilità e statistica": ("Calcolo combinatorio", "Probabilità condizionata"),
    "Fisica classica": ("Leggi di Newton", "Lavoro ed energia", "Moto rettilineo"),
    "Chimica generale": ("Tavola periodica", "Legami chimici", "Moli"),
    "Biologia": ("La cellula", "Mitosi e meiosi", "Genetica"),
    "Scienze della terra": ("Vulcani e terremoti", "I minerali"),
    "Programmazione": ("Cicli in Python", "Classi in Java", "Array e matrici"),
    "Database": ("Query SQL", "Modello entità-relazione"),
    "Algoritmi e computazione": ("Algoritmi di ordinamento", "Ricorsione"),
    "Economia aziendale": (
        "Partita doppia",
        "Bilancio d'esercizio",
        "Calcolo dell'IVA",
    ),
    "Tecnologia": ("Disegno tecnico", "I materiali"),
}

_BOOKING_NOTES: Final[tuple[str, ...]] = (
    "Porta il libro di testo e gli esercizi assegnati.",
    "Verifica la prossima settimana.",
    "Ha bisogno di ripartire dalle basi.",
    "Compiti delle vacanze ancora da finire.",
)

_TEACHER_NOTES: Final[tuple[str, ...]] = (
    "Lezione produttiva: abbiamo ripassato {topic} e svolto gli esercizi per casa.",
    "In vista della verifica servirebbe un'altra ora su {topic}.",
    "Mancava il materiale della scuola: abbiamo lavorato su schede stampate qui.",
    "Oggi poca concentrazione dopo la prima mezz'ora: meglio fare pause brevi.",
    "Ottimi progressi su {topic}: la verifica di ieri è andata bene.",
)

_MATHS_HIGH: Final = (
    "Algebra",
    "Geometria",
    "Analisi matematica",
    "Probabilità e statistica",
    "Fisica classica",
)
_MATHS_MIDDLE: Final = ("Aritmetica", "Algebra", "Geometria")
_ITALIAN: Final = (
    "Grammatica italiana",
    "Antologia",
    "Epica",
    "Letteratura italiana",
    "Produzione scritta",
    "Storia",
    "Geografia",
)
_ENGLISH: Final = ("Grammatica inglese", "Letteratura inglese", "Microlingua inglese")
_LATIN: Final = ("Grammatica latina", "Cultura latina", "Letteratura latina")
_GREEK: Final = ("Grammatica greca", "Cultura greca", "Letteratura greca")
_LANGUAGES: Final = (
    "Grammatica francese",
    "Grammatica tedesca",
    "Grammatica spagnola",
)


@dataclass(frozen=True)
class TeacherSpec:
    key: str
    first: str
    last: str
    gender: str
    # None: born on the day the script runs, so the home shows a birthday.
    born: date | None
    birthplace: str
    town: str
    since: int
    # Disciplines and the programme groups they are taught in.
    teaches: tuple[tuple[tuple[str, ...], tuple[str, ...]], ...]
    hours: tuple[tuple[int, str, str, str], ...]
    services: tuple[str, ...] = ()
    rating: str = "3.5"
    collaboration: CollaborationTypeEnum = CollaborationTypeEnum.VOLUNTEER
    high_school_student: bool = False
    school_education: str | None = None
    university_education: str | None = None
    paused: bool = False


_P: Final[str] = _PRESENCE
_O: Final[str] = _ONLINE
_AFTERNOON: Final = ("14:30", "18:30")
_EVENING: Final = ("20:00", "22:00")
_SATURDAY: Final = ("09:00", "12:30")

_TEACHERS: Final[tuple[TeacherSpec, ...]] = (
    TeacherSpec(
        "bardellin",
        "Giulia",
        "Bardellin",
        "F",
        date(2002, 4, 17),
        "Santorso",
        "Thiene",
        2024,
        ((_MATHS_HIGH, ("HIGH",)), (_MATHS_MIDDLE, ("MIDDLE",))),
        ((2, _P, *_AFTERNOON), (4, _P, *_AFTERNOON), (1, _O, *_EVENING)),
        rating="4.5",
        school_education="Liceo scientifico",
        university_education="Laurea in Matematica, Università di Padova",
    ),
    TeacherSpec(
        "belvadori",
        "Paolo",
        "Belvadori",
        "M",
        date(1954, 1, 25),
        "Vicenza",
        "Thiene",
        2019,
        ((_MATHS_HIGH, ("HIGH",)), (_MATHS_MIDDLE, ("MIDDLE",))),
        ((1, _P, *_AFTERNOON), (3, _P, *_AFTERNOON), (5, _P, *_AFTERNOON)),
        services=("Preparazione agli esami",),
        rating="5.0",
        school_education="Liceo scientifico",
        university_education="Laurea in Fisica, Università di Padova",
    ),
    TeacherSpec(
        "brentasso",
        "Andrea",
        "Brentasso",
        "M",
        date(2001, 8, 8),
        "Schio",
        "Schio",
        2023,
        (
            (_MATHS_HIGH + ("Programmazione", "Algoritmi e computazione"), ("HIGH",)),
            (_MATHS_MIDDLE, ("MIDDLE",)),
        ),
        ((3, _P, "15:00", "18:30"), (1, _O, *_EVENING), (4, _O, *_EVENING)),
        rating="4.0",
        school_education="Istituto tecnico tecnologico",
        university_education="Ingegneria informatica, Università di Padova",
    ),
    TeacherSpec(
        "caldarin",
        "Francesca",
        "Caldarin",
        "F",
        date(1975, 12, 3),
        "Bassano del Grappa",
        "Sarcedo",
        2020,
        ((_ENGLISH + ("Grammatica francese",), ("HIGH", "MIDDLE")),),
        ((1, _P, *_AFTERNOON), (4, _P, *_AFTERNOON), (6, _P, *_SATURDAY)),
        rating="4.5",
        collaboration=CollaborationTypeEnum.PAID,
        school_education="Liceo linguistico",
        university_education="Lingue e letterature straniere, Università di Verona",
    ),
    TeacherSpec(
        "casolini",
        "Luca",
        "Casolini",
        "M",
        date(2009, 2, 11),
        "Santorso",
        "Marano Vicentino",
        2026,
        ((_MATHS_MIDDLE + ("Grammatica inglese",), ("MIDDLE",)),),
        ((2, _P, "15:00", "17:30"), (3, _P, "15:00", "17:30")),
        rating="3.5",
        collaboration=CollaborationTypeEnum.PCTO,
        high_school_student=True,
        school_education="Liceo scientifico, quinto anno",
    ),
    TeacherSpec(
        "cerdagno",
        "Marta",
        "Cerdagno",
        "F",
        date(2000, 6, 29),
        "Thiene",
        "Thiene",
        2022,
        (
            (_ITALIAN, ("HIGH", "MIDDLE")),
            (("Grammatica latina", "Cultura latina", "Storia dell'arte"), ("LICEI",)),
        ),
        ((1, _P, *_AFTERNOON), (2, _P, *_AFTERNOON), (5, _P, *_AFTERNOON)),
        services=("Preparazione agli esami",),
        rating="4.5",
        school_education="Liceo classico",
        university_education="Lettere moderne, Università di Padova",
    ),
    TeacherSpec(
        "corvalli",
        "Davide",
        "Corvalli",
        "M",
        date(1990, 10, 15),
        "Vicenza",
        "Villaverla",
        2021,
        (
            (("Economia aziendale", "Diritto", "Economia politica"), ("TECNICI", "su")),
            (("Algebra", "Probabilità e statistica"), ("afm",)),
        ),
        ((4, _P, "15:00", "18:30"), (3, _O, *_EVENING)),
        rating="4.0",
        school_education="Istituto tecnico economico",
        university_education="Economia aziendale, Università di Verona",
    ),
    TeacherSpec(
        "dalvisi",
        "Anna",
        "Dalvisi",
        "F",
        None,
        "Padova",
        "Breganze",
        2023,
        (
            (
                ("Biologia", "Chimica generale", "Scienze della terra"),
                ("HIGH", "MIDDLE", "PRIMARY"),
            ),
        ),
        ((3, _P, *_AFTERNOON), (5, _P, *_AFTERNOON)),
        rating="4.0",
        school_education="Liceo scientifico",
        university_education="Scienze biologiche, Università di Padova",
    ),
    TeacherSpec(
        "demarzin",
        "Roberto",
        "Demarzin",
        "M",
        date(1950, 5, 5),
        "Verona",
        "Thiene",
        2018,
        (
            (_LATIN + ("Letteratura italiana", "Filosofia"), ("LICEI",)),
            (_GREEK, ("cla",)),
        ),
        ((2, _P, *_AFTERNOON), (4, _P, *_AFTERNOON), (6, _P, *_SATURDAY)),
        services=("Preparazione agli esami",),
        rating="5.0",
        school_education="Liceo classico",
        university_education="Lettere classiche, Università di Padova",
    ),
    TeacherSpec(
        "dolcimani",
        "Sara",
        "Dolcimani",
        "F",
        date(1996, 3, 22),
        "Santorso",
        "Carrè",
        2022,
        ((_LANGUAGES + ("Grammatica inglese",), ("HIGH", "MIDDLE")),),
        ((5, _P, *_AFTERNOON), (1, _O, *_AFTERNOON), (3, _O, *_EVENING)),
        rating="4.0",
        school_education="Liceo linguistico",
        university_education="Mediazione linguistica, Università di Padova",
    ),
    TeacherSpec(
        "ferlingo",
        "Matteo",
        "Ferlingo",
        "M",
        date(1999, 9, 12),
        "Thiene",
        "Zanè",
        2024,
        (
            (
                (
                    "Programmazione",
                    "Algoritmi e computazione",
                    "Database",
                    "Utilizzo del computer",
                ),
                ("TECNICI",),
            ),
            (("Algebra",), ("inf",)),
            (("Tecnologia", "Utilizzo del computer"), ("MIDDLE", "PRIMARY")),
        ),
        ((1, _O, *_EVENING), (4, _O, *_EVENING), (6, _O, *_SATURDAY)),
        rating="3.5",
        school_education="Istituto tecnico tecnologico",
        university_education="Informatica, Università di Padova",
    ),
    TeacherSpec(
        "fonsaghi",
        "Beatrice",
        "Fonsaghi",
        "F",
        date(1985, 2, 28),
        "Schio",
        "Santorso",
        2021,
        (
            (
                (
                    "Grammatica italiana",
                    "Produzione scritta",
                    "Lettura e comprensione",
                    "Aritmetica",
                    "Geometria",
                    "Storia",
                    "Geografia",
                ),
                ("PRIMARY",),
            ),
        ),
        ((1, _P, *_AFTERNOON), (3, _P, *_AFTERNOON)),
        services=("Metodo di studio",),
        rating="4.5",
        school_education="Liceo delle scienze umane",
        university_education="Scienze della formazione primaria, Università di Padova",
    ),
    TeacherSpec(
        "gambrasi",
        "Federico",
        "Gambrasi",
        "M",
        date(1997, 11, 19),
        "Napoli",
        "Thiene",
        2023,
        (
            (
                (
                    "Filosofia",
                    "Storia",
                    "Letteratura italiana",
                    "Psicologia",
                    "Pedagogia",
                    "Sociologia",
                ),
                ("HIGH",),
            ),
            (("Grammatica latina", "Cultura latina"), ("LICEI",)),
        ),
        ((1, _P, *_AFTERNOON), (3, _P, *_AFTERNOON), (6, _P, *_SATURDAY)),
        services=("Orientamento scolastico",),
        rating="4.0",
        school_education="Liceo classico",
        university_education="Filosofia, Università di Padova",
    ),
    TeacherSpec(
        "garvoli",
        "Valentina",
        "Garvoli",
        "F",
        date(1993, 7, 7),
        "Thiene",
        "Thiene",
        2020,
        (
            (
                (
                    "Aritmetica",
                    "Geometria",
                    "Biologia",
                    "Grammatica italiana",
                    "Antologia",
                ),
                ("MIDDLE",),
            ),
        ),
        ((2, _P, *_AFTERNOON), (3, _P, *_AFTERNOON), (4, _P, *_AFTERNOON)),
        services=("Metodo di studio", "Orientamento scolastico"),
        rating="4.5",
        school_education="Liceo delle scienze umane",
        university_education="Scienze dell'educazione, Università di Padova",
    ),
    TeacherSpec(
        "gelsomari",
        "Irene",
        "Gelsomari",
        "F",
        date(1999, 1, 19),
        "Thiene",
        "Thiene",
        2024,
        (
            (
                _ENGLISH + ("Grammatica italiana", "Antologia", "Produzione scritta"),
                ("HIGH", "MIDDLE"),
            ),
        ),
        ((2, _P, *_AFTERNOON), (3, _P, *_AFTERNOON), (5, _P, *_AFTERNOON)),
        rating="4.0",
        school_education="Liceo linguistico",
        university_education="Lingue e letterature straniere, Università di Padova",
    ),
    TeacherSpec(
        "grimbaldi",
        "Michele",
        "Grimbaldi",
        "M",
        date(1961, 9, 3),
        "Schio",
        "Schio",
        2021,
        (
            (_MATHS_HIGH, ("HIGH",)),
            (_MATHS_MIDDLE + ("Tecnologia",), ("MIDDLE",)),
        ),
        ((2, _P, *_AFTERNOON), (4, _P, *_AFTERNOON), (5, _P, *_AFTERNOON)),
        services=("Preparazione agli esami",),
        rating="4.5",
        school_education="Istituto tecnico industriale",
        university_education="Ingegneria meccanica, Università di Padova",
    ),
    TeacherSpec(
        "lavezzon",
        "Giorgia",
        "Lavezzon",
        "F",
        date(2003, 11, 27),
        "Santorso",
        "Zanè",
        2025,
        (
            (_ITALIAN, ("HIGH", "MIDDLE")),
            (("Grammatica latina", "Grammatica greca", "Cultura greca"), ("LICEI",)),
        ),
        ((1, _P, *_AFTERNOON), (3, _P, *_AFTERNOON), (4, _P, *_AFTERNOON)),
        rating="4.0",
        school_education="Liceo classico",
        university_education="Lettere classiche, Università di Padova",
    ),
    TeacherSpec(
        "lorbegni",
        "Alberto",
        "Lorbegni",
        "M",
        date(1958, 2, 14),
        "Thiene",
        "Villaverla",
        2020,
        (
            (("Economia aziendale", "Diritto", "Economia politica"), ("TECNICI", "su")),
            (("Algebra", "Probabilità e statistica", "Database"), ("TECNICI",)),
        ),
        ((1, _P, *_AFTERNOON), (3, _P, *_AFTERNOON), (1, _O, *_EVENING)),
        rating="4.0",
        school_education="Istituto tecnico commerciale",
        university_education="Economia e commercio, Università di Verona",
    ),
    TeacherSpec(
        "marcolani",
        "Nadia",
        "Marcolani",
        "F",
        date(1988, 6, 11),
        "Napoli",
        "Marano Vicentino",
        2023,
        ((_LANGUAGES + _ENGLISH, ("HIGH", "MIDDLE")),),
        (
            (2, _P, *_AFTERNOON),
            (4, _P, *_AFTERNOON),
            (3, _O, *_EVENING),
            (6, _O, *_SATURDAY),
        ),
        rating="4.5",
        collaboration=CollaborationTypeEnum.PAID,
        school_education="Liceo linguistico",
        university_education="Lingue e culture moderne, Università di Bologna",
    ),
    TeacherSpec(
        "mezzaroli",
        "Ilaria",
        "Mezzaroli",
        "F",
        date(1994, 4, 4),
        "Vicenza",
        "Sarcedo",
        2022,
        ((("Grammatica inglese",), ("MIDDLE",)),),
        (),
        rating="3.5",
        university_education="Lingue e culture moderne, Università di Verona",
        paused=True,
    ),
)

# Weekday, mode, start, end and requests: (subject or service, discipline, minutes).
type Request = tuple[str, str | None, int]
type Slot = tuple[int, str, str, str, tuple[Request, ...]]


@dataclass(frozen=True)
class ChildSpec:
    first: str
    gender: str
    program: str
    grade: int
    homeschooling: bool = False
    certifications: tuple[CertificationTypeEnum, ...] = ()
    dsa: str | None = None
    psych: bool = False
    returning: bool = True
    # Fixed weekly hours with their requests; empty means drawn at random.
    slots: tuple[Slot, ...] = ()
    prefers: tuple[str, ...] = ()
    avoids: tuple[str, ...] = ()
    early_exit: tuple[tuple[int, ...], str, str] | None = None
    # Born this many days after the day the script runs; None keeps it random.
    birthday_in: int | None = None
    years_late: int = 0


@dataclass(frozen=True)
class ParentSpec:
    first: str
    last: str
    gender: str
    born_year: int
    birthplace: str = "Vicenza"
    account: bool = True
    pickup_restriction: str | None = None


@dataclass(frozen=True)
class FamilySpec:
    surname: str
    town: str
    parents: tuple[ParentSpec, ...]
    children: tuple[ChildSpec, ...]


_DSA: Final = CertificationTypeEnum.DSA
_BES: Final = CertificationTypeEnum.BES
_ADHD: Final = CertificationTypeEnum.ADHD

# The demo account: a volunteer teacher for the middle school who is also the
# mother of two pupils.
_DEMO_USERNAME: Final[str] = "demo.utente"
_DEMO_TEACHER: Final = TeacherSpec(
    "campiverdi",
    "Elisa",
    "Campiverdi",
    "F",
    date(1987, 3, 9),
    "Thiene",
    "Thiene",
    2024,
    (
        (
            (
                "Grammatica italiana",
                "Antologia",
                "Produzione scritta",
                "Grammatica inglese",
            ),
            ("MIDDLE",),
        ),
        (("Aritmetica", "Geometria"), ("MIDDLE",)),
    ),
    ((2, _P, *_AFTERNOON), (3, _P, *_AFTERNOON), (4, _P, *_AFTERNOON)),
    rating="4.5",
    school_education="Liceo delle scienze umane",
)
_DEMO_FAMILY: Final = FamilySpec(
    "Ferragin",
    "Thiene",
    (ParentSpec("Andrea", "Ferragin", "M", 1985, "Schio"),),
    (
        ChildSpec(
            "Pietro",
            "M",
            "media",
            2,
            certifications=(_DSA,),
            dsa="Dislessia e disortografia",
            psych=True,
            slots=(
                (
                    1,
                    _P,
                    "14:30",
                    "16:30",
                    (("Italiano", "Grammatica italiana", 60), ("Inglese", None, 60)),
                ),
                (
                    3,
                    _P,
                    "14:30",
                    "16:30",
                    (("Matematica", "Geometria", 60), ("Metodo di studio", None, 60)),
                ),
            ),
            avoids=("casolini",),
        ),
        ChildSpec(
            "Giada",
            "F",
            "primaria",
            4,
            slots=(
                (3, _P, "15:00", "16:30", (("Italiano", None, 90),)),
                (5, _P, "15:00", "16:00", (("Matematica", None, 60),)),
            ),
        ),
    ),
)

_FAMILIES: Final[tuple[FamilySpec, ...]] = (
    FamilySpec(
        "Zandrelli",
        "Zanè",
        (ParentSpec("Elena", "Zandrelli", "F", 1983, "Santorso"),),
        (
            ChildSpec("Giacomo", "M", "media", 3),
            ChildSpec("Alice", "F", "primaria", 4, returning=False),
        ),
    ),
    FamilySpec(
        "Piovasco",
        "Thiene",
        (
            ParentSpec("Stefano", "Piovasco", "M", 1976, "Thiene"),
            ParentSpec("Paola", "Quarvelli", "F", 1979, "Breganze", account=False),
        ),
        (ChildSpec("Tommaso", "M", "cla_b", 2),),
    ),
    FamilySpec(
        "Rastelin",
        "Villaverla",
        (ParentSpec("Michela", "Ronchiveri", "F", 1975, "Vicenza"),),
        (ChildSpec("Nicola", "M", "afm_t", 4),),
    ),
    FamilySpec(
        "Salmavori",
        "Sarcedo",
        (ParentSpec("Roberta", "Salmavori", "F", 1981, "Thiene"),),
        (
            ChildSpec("Martina", "F", "lin_t", 3),
            ChildSpec("Emma", "F", "media", 1, returning=False),
        ),
    ),
    FamilySpec(
        "Scarsellini",
        "Marano Vicentino",
        (ParentSpec("Andrea", "Scarsellini", "M", 1977, "Schio"),),
        (
            ChildSpec(
                "Lorenzo",
                "M",
                "inf_b",
                1,
                certifications=(_ADHD,),
                psych=True,
                returning=False,
            ),
        ),
    ),
    FamilySpec(
        "Sorbazzi",
        "Thiene",
        (ParentSpec("Claudia", "Sorbazzi", "F", 1982, "Thiene"),),
        (ChildSpec("Giulia", "F", "su_b", 2),),
    ),
    FamilySpec(
        "Stellavi",
        "Carrè",
        (
            ParentSpec("Serena", "Tamburlin", "F", 1984, "Schio"),
            ParentSpec(
                "Davide",
                "Stellavi",
                "M",
                1980,
                "Vicenza",
                account=False,
                pickup_restriction="Su richiesta della famiglia: ritira solo la madre.",
            ),
        ),
        (ChildSpec("Riccardo", "M", "sci_b", 1, returning=False),),
    ),
    FamilySpec(
        "Tessarolin",
        "Thiene",
        (ParentSpec("Monica", "Toldavi", "F", 1979, "Bassano del Grappa"),),
        (
            ChildSpec(
                "Aurora",
                "F",
                "media",
                2,
                certifications=(_BES,),
                psych=True,
            ),
        ),
    ),
    FamilySpec(
        "Treviolin",
        "Schio",
        (
            ParentSpec("Fabio", "Treviolin", "M", 1972, "Schio"),
            ParentSpec("Ivana", "Valdagnin", "F", 1974, "Schio"),
        ),
        (
            ChildSpec("Matilde", "F", "cla_t", 4),
            ChildSpec("Leonardo", "M", "sci_t", 5, avoids=("brentasso",)),
        ),
    ),
    FamilySpec(
        "Vallorsi",
        "Breganze",
        (ParentSpec("Silvia", "Vallorsi", "F", 1985, "Breganze"),),
        (ChildSpec("Edoardo", "M", "afm_b", 2, avoids=("corvalli",)),),
    ),
    FamilySpec(
        "Ventolani",
        "Marano Vicentino",
        (ParentSpec("Daniela", "Zorvani", "F", 1986, "Schio"),),
        (ChildSpec("Ginevra", "F", "primaria", 5, birthday_in=1),),
    ),
    FamilySpec(
        "Bisolfi",
        "Zanè",
        (ParentSpec("Ivan", "Bisolfi", "M", 1981, "Thiene"),),
        (
            ChildSpec(
                "Samuele",
                "M",
                "media",
                1,
                returning=False,
                early_exit=((2, 4), "17:30", "Allenamento di calcio"),
            ),
        ),
    ),
    FamilySpec(
        "Calvenzi",
        "Thiene",
        (ParentSpec("Francesca", "Calvenzi", "F", 1983, "Santorso"),),
        (ChildSpec("Chiara", "F", "lin_b", 1, returning=False),),
    ),
    FamilySpec(
        "Dorsini",
        "Sarcedo",
        (ParentSpec("Giorgio", "Dorsini", "M", 1975, "Padova"),),
        (ChildSpec("Filippo", "M", "sci_t", 4),),
    ),
    FamilySpec(
        "Bradeanu",
        "Thiene",
        (ParentSpec("Ioana", "Bradeanu", "F", 1984, "Romania"),),
        (ChildSpec("Daniel", "M", "media", 3),),
    ),
    FamilySpec(
        "El Fassiri",
        "Schio",
        (ParentSpec("Samira", "El Fassiri", "F", 1982, "Marocco"),),
        (ChildSpec("Yasmine", "F", "su_t", 3),),
    ),
    FamilySpec(
        "Garbuglio",
        "Villaverla",
        (ParentSpec("Luca", "Garbuglio", "M", 1976, "Vicenza"),),
        (ChildSpec("Anna", "F", "inf_t", 3),),
    ),
    FamilySpec(
        "Lisandri",
        "Carrè",
        (ParentSpec("Paola", "Lisandri", "F", 1980, "Verona"),),
        (ChildSpec("Mattia", "M", "media", 2, homeschooling=True),),
    ),
    FamilySpec(
        "Marvelli",
        "Thiene",
        (ParentSpec("Roberto", "Marvelli", "M", 1973, "Thiene"),),
        (ChildSpec("Irene", "F", "cla_b", 1, returning=False),),
    ),
    FamilySpec(
        "Nesparin",
        "Thiene",
        (ParentSpec("Marta", "Olivani", "F", 1987, "Thiene"),),
        (ChildSpec("Davide", "M", "primaria", 3),),
    ),
    FamilySpec(
        "Parvalli",
        "Thiene",
        (ParentSpec("Katia", "Parvalli", "F", 1980, "Thiene"),),
        (
            ChildSpec("Elia", "M", "media", 1),
            ChildSpec("Viola", "F", "primaria", 2),
        ),
    ),
    FamilySpec(
        "Rosmarin",
        "Zanè",
        (ParentSpec("Gianluca", "Rosmarin", "M", 1974, "Schio"),),
        (ChildSpec("Arianna", "F", "sci_b", 2),),
    ),
    FamilySpec(
        "Sambrini",
        "Marano Vicentino",
        (ParentSpec("Sabrina", "Sambrini", "F", 1982, "Santorso"),),
        (ChildSpec("Tobia", "M", "media", 3),),
    ),
    FamilySpec(
        "Tolvedi",
        "Sarcedo",
        (ParentSpec("Giada", "Urbanin", "F", 1986, "Bassano del Grappa"),),
        (ChildSpec("Diego", "M", "afm_t", 3),),
    ),
    FamilySpec(
        "Vespolin",
        "Breganze",
        (
            ParentSpec("Simone", "Vespolin", "M", 1978, "Vicenza"),
            ParentSpec("Erika", "Borgolani", "F", 1981, "Breganze", account=False),
        ),
        (
            ChildSpec("Bianca", "F", "lin_t", 4),
            ChildSpec("Alessandro", "M", "media", 2),
        ),
    ),
    FamilySpec(
        "Cremisi",
        "Thiene",
        (ParentSpec("Elisabetta", "Cremisi", "F", 1979, "Thiene"),),
        (ChildSpec("Gaia", "F", "su_t", 5),),
    ),
    FamilySpec(
        "Fioravin",
        "Schio",
        (ParentSpec("Mauro", "Fioravin", "M", 1970, "Schio"),),
        (ChildSpec("Enrico", "M", "cla_t", 3),),
    ),
    FamilySpec(
        "Granvoli",
        "Villaverla",
        (ParentSpec("Valeria", "Granvoli", "F", 1985, "Vicenza"),),
        (ChildSpec("Rebecca", "F", "primaria", 1, returning=False),),
    ),
    FamilySpec(
        "Ledrani",
        "Carrè",
        (ParentSpec("Cristina", "Ledrani", "F", 1983, "Schio"),),
        (ChildSpec("Christian", "M", "inf_b", 2),),
    ),
    FamilySpec(
        "Morsellin",
        "Zanè",
        (ParentSpec("Lisa", "Morsellin", "F", 1984, "Thiene"),),
        (ChildSpec("Noemi", "F", "media", 1, returning=False),),
    ),
    FamilySpec(
        "Lleshaj",
        "Thiene",
        (ParentSpec("Arben", "Lleshaj", "M", 1979, "Albania"),),
        (ChildSpec("Klea", "F", "sci_t", 3),),
    ),
    FamilySpec(
        "Rovighin",
        "Breganze",
        (ParentSpec("Mirko", "Rovighin", "M", 1977, "Vicenza"),),
        (ChildSpec("Kevin", "M", "eno_b", 2),),
    ),
)

# Of age and answering for themselves: they book and pay on their own.
_ADULT_PUPILS: Final[tuple[tuple[str, str, str, str, int, str, int], ...]] = (
    ("Giorgia", "Selvaggin", "F", "afm_t", 5, "Thiene", 1),
    ("Mattia", "Tornavi", "M", "inf_t", 5, "Schio", 1),
)

# First, last, gender, born, birthplace, town, role.
_ADMINISTRATORS: Final[tuple[tuple, ...]] = (
    (
        "Giovanna",
        "Molvenari",
        "F",
        date(1962, 3, 14),
        "Thiene",
        "Thiene",
        AdministratorRoleEnum.PRESIDENT,
    ),
    (
        "Luigi",
        "Montebasso",
        "M",
        date(1958, 11, 2),
        "Schio",
        "Zanè",
        AdministratorRoleEnum.VICE_PRESIDENT,
    ),
    (
        "Maria Grazia",
        "Nardovin",
        "F",
        date(1966, 7, 21),
        "Vicenza",
        "Thiene",
        AdministratorRoleEnum.TREASURER,
    ),
    (
        "Chiara",
        "Orsevani",
        "F",
        date(1988, 5, 9),
        "Santorso",
        "Thiene",
        AdministratorRoleEnum.OTHER,
    ),
)


def _plain(value: str) -> str:
    return unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()


def _letters(value: str) -> str:
    return "".join(
        character for character in _plain(value).upper() if character.isalpha()
    )


def _slug(first: str, last: str) -> str:
    return ".".join(
        _plain(part).lower().replace(" ", "").replace("'", "") for part in (first, last)
    )


def _code_part(value: str, *, given_name: bool) -> str:
    letters = _letters(value)
    consonants = [character for character in letters if character not in _VOWELS]
    vowels = [character for character in letters if character in _VOWELS]

    # Given names with four or more consonants skip the second one.
    if given_name and len(consonants) >= 4:
        consonants = [consonants[0], consonants[2], consonants[3]]

    return "".join([*consonants, *vowels, "X", "X", "X"])[:3]


def tax_code(first: str, last: str, gender: str, born: date, place: str) -> str:
    day = born.day + (40 if gender == "F" else 0)
    stem = (
        _code_part(last, given_name=False)
        + _code_part(first, given_name=True)
        + f"{born.year % 100:02d}{_MONTH_LETTERS[born.month - 1]}{day:02d}{place}"
    )
    total = sum(
        (
            _TAX_CODE_ODD_POSITION_VALUES[character]
            if index % 2 == 0
            else _TAX_CODE_EVEN_POSITION_VALUES[character]
        )
        for index, character in enumerate(stem)
    )

    return stem + _TAX_CODE_CHECK_CHARACTERS[total % len(_TAX_CODE_CHECK_CHARACTERS)]


def _clock(value: str) -> time:
    hours, minutes = value.split(":")

    return time(int(hours), int(minutes))


def _shift(moment: time, minutes: int) -> time:
    total = moment.hour * 60 + moment.minute + minutes

    return time(total // 60, total % 60)


def _at(day: date, moment: time) -> datetime:
    return datetime.combine(day, moment, tzinfo=now_in_rome().tzinfo)


def _long_date(day: date) -> str:
    return f"{_WEEKDAYS[day.weekday()]} {day.day} {_MONTHS[day.month - 1]}"


def _pdf(lines: Sequence[str]) -> bytes:
    def escaped(line: str) -> str:
        return line.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")

    stream = (
        "BT /F1 12 Tf 16 TL 72 770 Td "
        + " ".join(f"({escaped(line)}) Tj T*" for line in lines)
        + " ET"
    ).encode("cp1252")
    bodies = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
        b"/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica "
        b"/Encoding /WinAnsiEncoding >>",
        b"<< /Length %d >>\nstream\n%s\nendstream" % (len(stream), stream),
    ]
    document = bytearray(b"%PDF-1.4\n")
    offsets = []

    for number, body in enumerate(bodies, start=1):
        offsets.append(len(document))
        document += b"%d 0 obj\n%s\nendobj\n" % (number, body)

    table = len(document)
    document += b"xref\n0 %d\n0000000000 65535 f \n" % (len(bodies) + 1)
    document += b"".join(b"%010d 00000 n \n" % offset for offset in offsets)
    document += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (
        len(bodies) + 1,
        table,
    )

    return bytes(document)


@dataclass
class Pupil:
    person: Person
    program: str
    level: EducationLevelEnum
    bookers: list[str]
    slots: list[Slot]
    needs: list[tuple[str, int]]
    prefers: list[str] = field(default_factory=list)
    avoids: set[str] = field(default_factory=set)
    fixed: bool = False


@dataclass
class Taught:
    lesson: Lesson
    start: time
    end: time
    online: bool
    students: int
    discipline: int | None
    service: str | None


@dataclass
class Placed:
    booking: Booking
    request: tuple[str | None, int | None, str | None]
    minutes: int


class Seeder:
    def __init__(
        self,
        session: AsyncSession,
        now: datetime,
        password: str,
        kept: set[str],
        catalogue: dict,
    ) -> None:
        self.session = session
        self.catalogue = catalogue
        self.now = now
        self.today = now.date()
        self.rng = random.Random(20260914)
        self.kept = kept
        self.demo_hash = hash_password(password)
        self.locked_hash = hash_password(secrets.token_urlsafe(32))
        self.school_year = school_year_start(self.today)
        self.season_start = self._first_monday(date(self.school_year, 9, 14))
        self.window_end = compute_available_window(now)[1]
        self.tax_codes: set[str] = set(kept)
        self.slugs: set[str] = set()
        self.usernames: set[str] = set()
        self.people: dict[str, Person] = {}
        self.disciplines: dict[str, AssociationSubject] = {}
        self.ministry: dict[tuple[EducationLevelEnum, str], MinistrySubject] = {}
        self.ministry_disciplines: dict[int, list[str]] = {}
        self.programs: dict[str, StudyProgram] = {}
        self.program_levels: dict[str, EducationLevelEnum] = {}
        self.program_subjects: dict[str, set[str]] = {}
        self.groups: dict[str, tuple[str, ...]] = {}
        self.schools: dict[int, list[School]] = defaultdict(list)
        self.rooms: list[Room] = []
        self.services: set[str] = set()
        self.teachers: dict[str, Person] = {}
        self.teacher_specs: dict[str, TeacherSpec] = {}
        self.competences: dict[str, set[tuple[int, int]]] = defaultdict(set)
        self.teacher_services: dict[str, set[str]] = defaultdict(set)
        self.pupils: list[Pupil] = []
        self.openings: dict[date, list[tuple[str, time, time]]] = {}
        self.admins: dict[AdministratorRoleEnum, Person] = {}
        self.psychologist: Person | None = None
        self.published: list[tuple[date, TimeBandEnum]] = []
        self.dropped = 0
        self.past_lessons: list[tuple[Lesson, Person, str, str]] = []
        # The Friday after next closes early for the members' meeting.
        self.meeting_day = self.today + timedelta(
            days=(4 - self.today.weekday()) % 7 + 7,
        )

    @staticmethod
    def _first_monday(day: date) -> date:
        return day + timedelta(days=(7 - day.weekday()) % 7)

    def _year_ago(self, years: int = 1) -> int:
        return self.school_year - years

    # Accounts and memberships carry real dates: created before they were used.
    def _moment(self, day: date, hour: int = 9) -> datetime:
        return _at(day, time(hour, self.rng.randrange(0, 60, 5)))

    def _born(self, year: int) -> date:
        return date(year, self.rng.randint(1, 12), self.rng.randint(1, 28))

    def _email(self, first: str, last: str) -> str:
        base = _slug(first, last)
        slug = base
        counter = 2

        while slug in self.slugs:
            slug = f"{base}{counter}"
            counter += 1

        self.slugs.add(slug)

        return _EMAIL.format(slug=slug)

    def _username(self, first: str, last: str) -> str:
        base = _slug(first, last)
        name = base
        counter = 2

        while name in self.usernames:
            name = f"{base}.{counter}"
            counter += 1

        self.usernames.add(name)

        return name

    async def person(
        self,
        first: str,
        last: str,
        gender: str,
        born: date,
        birthplace: str,
        town: str,
    ) -> Person:
        abroad = birthplace in _COUNTRIES
        place = _COUNTRIES[birthplace] if abroad else _TOWNS[birthplace][1]
        code = tax_code(first, last, gender, born, place)

        # Two people alike in name and birth would share a code; nudge the day.
        while code in self.tax_codes:
            born += timedelta(days=1)
            code = tax_code(first, last, gender, born, place)

        self.tax_codes.add(code)
        province, _, postal_code = _TOWNS[town]
        street_type, street = self.rng.choice(_STREETS)
        person = Person(
            tax_code=code,
            first_name=first,
            last_name=last,
            gender=GenderEnum(gender),
            birth_date=born,
            birth_city=None if abroad else birthplace,
            birth_nation=birthplace if abroad else "Italia",
            birth_province=BORN_ABROAD_PROVINCE if abroad else _TOWNS[birthplace][0],
            email=self._email(first, last),
            phone=f"+393{self.rng.randint(10, 99)}{self.rng.randint(1000000, 9999999)}",
            residence_type=street_type,
            residence_address=street,
            residence_street_number=str(self.rng.randint(1, 120)),
            residence_city=town,
            residence_province=province,
            postal_code=postal_code,
            created_at=self._moment(date(self._year_ago(), 9, 1)),
        )
        self.session.add(person)
        self.people[code] = person
        await self.session.flush()

        return person

    def account(
        self,
        person: Person,
        username: str | None,
        *,
        autonomous: bool = False,
        role: str | None = None,
    ) -> Account:
        name = username or self._username(person.first_name, person.last_name)
        self.usernames.add(name)
        joined = self.season_start - timedelta(days=self.rng.randint(5, 30))
        created = self._moment(joined)
        account = Account(
            tax_code=person.tax_code,
            username=name,
            status=AccountStatusEnum.ACTIVE,
            password_hash=(
                self.demo_hash if name == _DEMO_USERNAME else self.locked_hash
            ),
            last_login=max(
                created + timedelta(hours=1),
                self.now - timedelta(hours=self.rng.randint(2, 200)),
            ),
            password_reset_required=False,
            autonomous_bookings=autonomous,
            last_active_role=role,
            onboarding_completed_at=created + timedelta(minutes=5),
            terms_accepted_at=created + timedelta(minutes=4),
            created_at=created,
        )
        self.session.add(account)

        return account

    async def member(
        self,
        person: Person,
        *,
        returning: bool,
        joined: date | None = None,
    ) -> Member:
        signed = joined or min(
            self.today - timedelta(days=1),
            self.season_start - timedelta(days=self.rng.randint(0, 20)),
        )
        member = Member(
            tax_code=person.tax_code,
            payment_method=self.rng.choice(
                [PaymentMethodEnum.CASH, PaymentMethodEnum.BANK_TRANSFER],
            ),
            statute_acknowledged=True,
            regulation_acknowledged=True,
            video_surveillance_acknowledged=True,
            special_category_data_consent=True,
            newsletter_consent=self.rng.random() < 0.6,
            consents_signed_at=signed,
        )
        self.session.add(member)
        await self.session.flush()
        year = self.today.year

        start = date(year, 1, 1) if returning and year > self.school_year else signed

        # The calendar year in force, plus the one before for those coming back.
        self.session.add(
            Membership(
                member_tax_code=person.tax_code,
                year=year,
                start_date=start,
                end_date=date(year, 12, 31),
                renewal_period_days=31,
            ),
        )

        if returning:
            previous = year - 1
            self.session.add(
                Membership(
                    member_tax_code=person.tax_code,
                    year=previous,
                    start_date=date(previous, 9, self.rng.randint(1, 25)),
                    end_date=date(previous, 12, 31),
                    renewal_period_days=31,
                ),
            )

        return member

    async def staff(
        self,
        person: Person,
        collaboration: CollaborationTypeEnum = CollaborationTypeEnum.VOLUNTEER,
    ) -> None:
        self.session.add(
            Staff(tax_code=person.tax_code, collaboration_type=collaboration),
        )
        await self.session.flush()

    # The catalogue keeps its ids: nothing else points at them yet.
    async def catalogues(self) -> None:
        catalogue = self.catalogue
        rows = (
            (AssociationSubject, "association_subjects"),
            (MinistrySubject, "ministry_subjects"),
            (StudyProgram, "study_programs"),
            (School, "schools"),
        )

        for model, key in rows:
            self.session.add_all(model(**row) for row in catalogue[key])

        await self.session.flush()
        self.session.add_all(
            MinistryAssociationSubject(**row)
            for row in catalogue["ministry_association_subjects"]
        )
        self.session.add_all(
            StudyProgramSubject(**row) for row in catalogue["study_program_subjects"]
        )
        self.session.add_all(
            SchoolStudyProgram(**row) for row in catalogue["school_study_programs"]
        )

        for _, table in rows:
            await self.session.execute(
                text(
                    f"SELECT setval(pg_get_serial_sequence('{table}', 'id'), "
                    f"(SELECT coalesce(max(id), 0) + 1 FROM {table}), false)",
                ),
            )

        disciplines = {
            row["id"]: row["name"] for row in catalogue["association_subjects"]
        }
        ministry = {row["id"]: row for row in catalogue["ministry_subjects"]}

        for subject in await self.session.scalars(select(AssociationSubject)):
            self.disciplines[subject.name] = subject

        for subject in await self.session.scalars(select(MinistrySubject)):
            self.ministry[(EducationLevelEnum(subject.level), subject.name)] = subject

        for row in catalogue["ministry_association_subjects"]:
            self.ministry_disciplines.setdefault(row["ministry_subject_id"], []).append(
                disciplines[row["association_subject_id"]],
            )

        programs = list(await self.session.scalars(select(StudyProgram)))

        for key, (level, sector, name, track) in _PROGRAM_KEYS.items():
            program = next(
                (
                    row
                    for row in programs
                    if row.level == level
                    and row.sector == sector
                    and row.high_school_track == track
                    and (
                        row.name == name
                        or (sector is None and row.name.startswith(name))
                    )
                ),
                None,
            )

            if program is None:
                raise SystemExit(f"Percorso non trovato nel catalogo: {name}")

            self.programs[key] = program
            self.program_levels[key] = EducationLevelEnum(program.level)
            self.program_subjects[key] = {
                ministry[row["ministry_subject_id"]]["name"]
                for row in catalogue["study_program_subjects"]
                if row["study_program_id"] == program.id
            }

        keys = list(_PROGRAM_KEYS)
        levels = self.program_levels
        self.groups = {
            "PRIMARY": tuple(key for key in keys if levels[key] == _PRIMARY),
            "MIDDLE": tuple(key for key in keys if levels[key] == _MIDDLE),
            "HIGH": tuple(key for key in keys if levels[key] == _HIGH),
            "LICEI": tuple(key for key in keys if self.programs[key].sector == "Liceo"),
            "TECNICI": tuple(
                key
                for key in keys
                if (self.programs[key].sector or "").startswith("Istituto tecnico")
            ),
        }

        for key in keys:
            self.groups.setdefault(key.split("_")[0], ())
            self.groups[key.split("_")[0]] += (key,)

        schools = {
            school.id: school for school in await self.session.scalars(select(School))
        }

        for row in catalogue["school_study_programs"]:
            self.schools[row["study_program_id"]].append(schools[row["school_id"]])

        for name, description in _SERVICES:
            self.session.add(Service(name=name, description=description))
            self.services.add(name)

        for name, capacity, description in _ROOMS:
            room = Room(name=name, capacity=capacity, description=description)
            self.session.add(room)
            self.rooms.append(room)

        for name, description, cost in _COURSES:
            self.session.add(Course(name=name, description=description, cost=cost))

        await self.session.flush()

    # Whether the discipline is part of some subject of the programme.
    def _taught_in(self, discipline: str, program: str) -> bool:
        level = self.program_levels[program]

        subjects = [
            self.ministry[(level, name)].id for name in self.program_subjects[program]
        ]

        return any(
            discipline in self.ministry_disciplines.get(subject, [])
            for subject in subjects
        )

    async def opening_hours(self) -> None:
        effective = date(self.school_year, 9, 1)

        for weekday, mode, start, end in _WEEKLY_HOURS:
            self.session.add(
                WeeklyTemplate(
                    weekday=weekday,
                    mode=mode,
                    start_time=_clock(start),
                    end_time=_clock(end),
                    effective_from=effective,
                ),
            )

        eve = date(self.school_year, 12, 24)
        christmas = {eve + timedelta(days=offset) for offset in range(14)}
        last = date(self.school_year + 1, 12, 31)
        day = effective

        while day <= last:
            holiday = holidays_for_year(day.year).get(day)
            closure = holiday or ("Vacanze di Natale" if day in christmas else None)

            if closure is not None:
                for mode in (_PRESENCE, _ONLINE):
                    self.session.add(
                        OpeningDay(date=day, mode=mode, is_override=True, note=closure),
                    )
            else:
                rows = []

                for weekday, mode, start, end in _WEEKLY_HOURS:
                    if weekday != day.isoweekday():
                        continue

                    opens, closes = _clock(start), _clock(end)
                    note = None

                    if day == self.meeting_day and mode == _PRESENCE:
                        closes = time(17)
                        note = "Chiusura anticipata per l'assemblea dei soci"

                    rows.append((mode, opens, closes))
                    self.session.add(
                        OpeningDay(
                            date=day,
                            mode=mode,
                            start_time=opens,
                            end_time=closes,
                            is_override=note is not None,
                            note=note,
                        ),
                    )

                if rows:
                    self.openings[day] = rows

            day += timedelta(days=1)

        await self.session.flush()

    def _opening_has(self, day: date, mode: str, start: time, end: time) -> bool:
        return any(
            row_mode == mode and opens <= start and end <= closes
            for row_mode, opens, closes in self.openings.get(day, [])
        )

    async def board(self) -> None:
        for first, last, gender, born, birthplace, town, role in _ADMINISTRATORS:
            person = await self.person(first, last, gender, born, birthplace, town)
            await self.member(person, returning=True)
            await self.staff(person)
            self.session.add(
                Administrator(
                    tax_code=person.tax_code,
                    role=role,
                    other_role=(
                        "Segreteria" if role == AdministratorRoleEnum.OTHER else None
                    ),
                ),
            )
            self.account(person, None)
            self.admins[role] = person

        psychologist = await self.person(
            "Laura",
            "Pedrovani",
            "F",
            date(1985, 9, 30),
            "Padova",
            "Thiene",
        )
        await self.member(psychologist, returning=True)
        await self.staff(psychologist, CollaborationTypeEnum.PAID)
        self.session.add(Psychologist(tax_code=psychologist.tax_code))
        self.account(psychologist, None)
        self.psychologist = psychologist

        await self.session.flush()

    async def staff_room(self) -> None:
        for spec in (*_TEACHERS, _DEMO_TEACHER):
            born = spec.born or self.today.replace(year=1998)
            person = await self.person(
                spec.first,
                spec.last,
                spec.gender,
                born,
                spec.birthplace,
                spec.town,
            )
            member = await self.member(person, returning=spec.since < self.school_year)

            if spec.paused:
                member.collaborating_active = False
                member.collaboration_paused_at = self._moment(
                    self.season_start + timedelta(days=10),
                )

            await self.staff(person, spec.collaboration)
            self.session.add(
                Teacher(
                    tax_code=person.tax_code,
                    is_high_school_student=spec.high_school_student,
                    school_education=spec.school_education,
                    university_education=spec.university_education,
                    rating=Decimal(spec.rating),
                ),
            )

            if spec is _DEMO_TEACHER:
                self.account(person, _DEMO_USERNAME, role="PARENT")
            else:
                self.account(person, None)

            self.teachers[spec.key] = person
            self.teacher_specs[spec.key] = spec

        await self.session.flush()

        for spec in self.teacher_specs.values():
            person = self.teachers[spec.key]
            since = date(spec.since, 9, 1)

            for disciplines, groups in spec.teaches:
                programs = {
                    program for group in groups for program in self.groups[group]
                }

                for discipline in disciplines:
                    for program in sorted(programs):
                        if not self._taught_in(discipline, program):
                            continue

                        pair = (
                            self.disciplines[discipline].id,
                            self.programs[program].id,
                        )

                        if pair in self.competences[spec.key]:
                            continue

                        self.competences[spec.key].add(pair)
                        self.session.add(
                            TeachingCompetence(
                                teacher_tax_code=person.tax_code,
                                association_subject_id=pair[0],
                                study_program_id=pair[1],
                                valid_from=since,
                            ),
                        )

            for service in spec.services:
                self.teacher_services[spec.key].add(service)
                self.session.add(
                    TeacherService(
                        teacher_tax_code=person.tax_code,
                        service_name=service,
                        valid_from=since,
                    ),
                )

        await self.session.flush()

    def _pupil_born(self, child: ChildSpec, level: EducationLevelEnum) -> date:
        offset = {_PRIMARY: 0, _MIDDLE: 5, _HIGH: 8}[level]
        year = self.school_year - 5 - offset - child.grade - child.years_late

        if child.birthday_in is not None:
            day = self.today + timedelta(days=child.birthday_in)

            return date(year, day.month, min(day.day, 28))

        return self._born(year)

    # A school of the programme in the pupil's town, else in Thiene, else any.
    def _school_for(self, program: str, town: str) -> School | None:
        options = self.schools.get(self.programs[program].id, [])

        for place in (town, "Thiene"):
            nearby = [school for school in options if school.city == place]

            if nearby:
                return self.rng.choice(nearby)

        return self.rng.choice(options) if options else None

    def _enroll(self, student: Person, child: ChildSpec, town: str) -> None:
        program = self.programs[child.program]
        school = None if child.homeschooling else self._school_for(child.program, town)
        self.session.add(
            SchoolEnrollment(
                student_tax_code=student.tax_code,
                study_program_id=program.id,
                school_id=school.id if school else None,
                homeschooling=school is None,
                start_year=self.school_year,
                grade=child.grade,
            ),
        )

        if not child.returning:
            return

        previous_key, previous_grade = child.program, child.grade - 1

        # A first year comes from the last one of the school before.
        if previous_grade < program.min_year:
            previous_key = _PREVIOUS_PROGRAM.get(child.program)

            if previous_key is None:
                return

            previous_grade = self.programs[previous_key].max_year

        previous_school = school

        if school is not None and previous_key != child.program:
            previous_school = self._school_for(previous_key, town)

        self.session.add(
            SchoolEnrollment(
                student_tax_code=student.tax_code,
                study_program_id=self.programs[previous_key].id,
                school_id=previous_school.id if previous_school else None,
                homeschooling=previous_school is None,
                start_year=self.school_year - 1,
                grade=previous_grade,
            ),
        )

    @staticmethod
    def _weight(subject: str) -> int:
        return next(
            (weight for piece, weight in _NEED_WEIGHTS if piece in subject),
            0,
        )

    def _needs(self, child: ChildSpec) -> list[tuple[str, int]]:
        level = self.program_levels[child.program]
        pool = [
            (name, weight)
            for name in sorted(self.program_subjects[child.program])
            if (weight := self._weight(name))
        ]

        if level != _HIGH:
            pool.append(("Metodo di studio", 1))

        if child.grade == self.programs[child.program].max_year and level != _PRIMARY:
            pool.append(("Preparazione agli esami", 1))

        count = min(len(pool), self.rng.choice([2, 2, 3]))
        chosen: list[tuple[str, int]] = []

        while len(chosen) < count:
            names = [name for name, _ in pool if name not in dict(chosen)]
            weights = [weight for name, weight in pool if name not in dict(chosen)]
            name = self.rng.choices(names, weights)[0]
            chosen.append((name, dict(pool)[name]))

        # Highest weight first: the random hours are placed around it.
        return sorted(chosen, key=lambda row: -row[1])

    def _coverable(self, need: str, program: str, weekday: int, mode: str) -> bool:
        for key, spec in self.teacher_specs.items():
            if spec.paused:
                continue

            hours = [
                (row_mode, _clock(start), _clock(end))
                for row_weekday, row_mode, start, end in spec.hours
                if row_weekday == weekday
            ]

            if not any(row_mode in (mode, _PRESENCE) for row_mode, _, _ in hours):
                continue

            if need in self.services:
                if need in self.teacher_services[key]:
                    return True

                continue

            level = self.program_levels[program]
            ministry = self.ministry.get((level, need))

            if ministry is None:
                continue

            program_id = self.programs[program].id

            if any(
                (self.disciplines[discipline].id, program_id) in self.competences[key]
                for discipline in self.ministry_disciplines.get(ministry.id, [])
            ):
                return True

        return False

    def _random_slots(
        self,
        child: ChildSpec,
        needs: list[tuple[str, int]],
    ) -> list[Slot]:
        level = self.program_levels[child.program]
        count = self.rng.choice([1, 2] if level == _PRIMARY else [2, 2, 3])
        top = needs[0][0]
        slots: list[Slot] = []
        weekdays = [1, 2, 3, 4, 5]
        self.rng.shuffle(weekdays)

        for weekday in weekdays:
            if len(slots) == count:
                break

            mode = _PRESENCE
            start = self.rng.choice(["14:30", "15:00", "15:30", "16:00"])
            length = self.rng.choice([60, 90, 120, 120, 150, 180])

            if level == _HIGH and self.rng.random() < 0.25:
                mode = _ONLINE

                if weekday in (1, 3, 4) and self.rng.random() < 0.5:
                    start = "20:00"
                    length = self.rng.choice([60, 120])

            if level == _PRIMARY:
                length = min(length, 120)

            end = _shift(_clock(start), length)
            closes = time(22) if start == "20:00" else time(18, 30)

            if end > closes:
                end = closes

            if not self._coverable(top, child.program, weekday, mode):
                continue

            slots.append((weekday, mode, start, end.strftime("%H:%M"), ()))

        if level == _HIGH and self.rng.random() < 0.15:
            slots.append((6, _PRESENCE, "09:30", "11:30", ()))

        return slots

    async def families(self) -> None:
        await self._family(_DEMO_FAMILY, existing=self.teachers[_DEMO_TEACHER.key])

        for family in _FAMILIES:
            await self._family(family)

        for first, last, gender, program, grade, town, years_late in _ADULT_PUPILS:
            child = ChildSpec(first, gender, program, grade, years_late=years_late)
            level = self.program_levels[program]
            person = await self.person(
                first,
                last,
                gender,
                self._pupil_born(child, level),
                "Santorso",
                town,
            )
            await self._student(person, child, level, town=town)
            self.account(person, None)
            await self._add_pupil(person, child, level, [person.tax_code])

        await self.session.flush()

    async def _family(self, family: FamilySpec, existing: Person | None = None) -> None:
        parents: list[tuple[Person, ParentSpec | None]] = []

        if existing is not None:
            self.session.add(Parent(tax_code=existing.tax_code))
            parents.append((existing, None))

        for spec in family.parents:
            person = await self.person(
                spec.first,
                spec.last,
                spec.gender,
                self._born(spec.born_year),
                spec.birthplace,
                family.town,
            )
            self.session.add(Parent(tax_code=person.tax_code))

            if spec.account:
                self.account(person, None)

            parents.append((person, spec))

        await self.session.flush()

        for child in family.children:
            level = self.program_levels[child.program]
            person = await self.person(
                child.first,
                family.surname,
                child.gender,
                self._pupil_born(child, level),
                "Santorso",
                family.town,
            )
            await self._student(person, child, level, town=family.town)

            for parent, spec in parents:
                restriction = spec.pickup_restriction if spec else None
                self.session.add(
                    ParentalResponsibility(
                        parent_tax_code=parent.tax_code,
                        child_tax_code=person.tax_code,
                        authorized_pickup=restriction is None,
                        pickup_restriction_reason=restriction,
                    ),
                )

            # A parent who teaches here is never given their own child.
            excluded = {_DEMO_TEACHER.key} if existing is not None else set()
            await self._add_pupil(
                person,
                child,
                level,
                [parent.tax_code for parent, _ in parents],
                excluded=excluded,
            )

    async def _student(
        self,
        person: Person,
        child: ChildSpec,
        level: EducationLevelEnum,
        *,
        town: str,
    ) -> None:
        await self.member(person, returning=child.returning)
        tariffs = {
            _PRIMARY: [HomeworkTariffEnum.PRIMARY_MONTHLY],
            _MIDDLE: [
                HomeworkTariffEnum.MIDDLE_HOURLY,
                HomeworkTariffEnum.MIDDLE_PACKAGE,
            ],
            _HIGH: [HomeworkTariffEnum.HIGH_HOURLY, HomeworkTariffEnum.HIGH_PACKAGE],
        }
        early_exit = child.early_exit
        self.session.add(
            Student(
                tax_code=person.tax_code,
                certification_types=list(child.certifications),
                certification_dsa_detail=child.dsa,
                homework_tariff=self.rng.choice(tariffs[level]),
                mandatory_psych_meetings_acknowledged=True,
                authorized_early_exit=early_exit is not None,
            ),
        )
        await self.session.flush()

        if early_exit is not None:
            weekdays, leaves, reason = early_exit
            self.session.add(
                EarlyExitSchedule(
                    student_tax_code=person.tax_code,
                    ordinal=1,
                    weekdays=list(weekdays),
                    exit_time=_clock(leaves),
                    reason=reason,
                ),
            )

        if child.psych:
            started = self.season_start + timedelta(days=self.rng.randint(0, 10))
            self.session.add(
                PsychologicalSupport(tax_code=person.tax_code, start_date=started),
            )

        self._enroll(person, child, town)
        await self.session.flush()

    async def _add_pupil(
        self,
        person: Person,
        child: ChildSpec,
        level: EducationLevelEnum,
        bookers: list[str],
        *,
        excluded: set[str] | None = None,
    ) -> None:
        needs = self._needs(child)
        slots = list(child.slots) or self._random_slots(child, needs)
        self.pupils.append(
            Pupil(
                person=person,
                program=child.program,
                level=level,
                bookers=bookers,
                slots=slots,
                needs=needs,
                prefers=list(child.prefers),
                avoids=set(child.avoids) | (excluded or set()),
                fixed=bool(child.slots),
            ),
        )

        for key in child.avoids:
            since = self.season_start + timedelta(days=self.rng.randint(0, 14))
            self.session.add(
                StudentNotPreferredTeacher(
                    student_tax_code=person.tax_code,
                    teacher_tax_code=self.teachers[key].tax_code,
                    valid_from=since,
                ),
            )

        await self.session.flush()

    async def others(self) -> None:
        for first, last, gender, born, course in (
            ("Gianni", "Vercellin", "M", date(1949, 6, 2), "Laboratorio di scacchi"),
            ("Lucia", "Zelandi", "F", date(1972, 1, 30), "Corso di fotografia"),
        ):
            person = await self.person(first, last, gender, born, "Thiene", "Thiene")
            await self.member(person, returning=True)
            self.session.add(
                CourseParticipant(
                    tax_code=person.tax_code,
                    course_type=course,
                    medical_certificate_expiration=date(self.school_year + 1, 6, 30),
                ),
            )

        await self.session.flush()

    # One request turned into the booking's columns: (ministry id, discipline, service).
    # Teachers in that day who could follow the pupil there, at those hours.
    def _within_reach(
        self,
        pupil: Pupil,
        present: dict[str, list[Availability]],
        mode: str,
        start: time,
        end: time,
    ) -> list[str]:
        return [
            key
            for key, rows in present.items()
            if key not in pupil.avoids
            and any(
                (row.mode == mode or row.mode == _PRESENCE)
                and row.start_time < end
                and start < row.end_time
                for row in rows
            )
        ]

    def _taught_by(
        self,
        pupil: Pupil,
        need: str,
        teachers: list[str],
    ) -> list[str]:
        if need in self.services:
            offered = any(need in self.teacher_services[key] for key in teachers)

            return [need] if offered else []

        ministry = self.ministry.get((pupil.level, need))

        if ministry is None:
            return []

        program_id = self.programs[pupil.program].id

        return [
            name
            for name in self.ministry_disciplines[ministry.id]
            if any(
                (self.disciplines[name].id, program_id) in self.competences[key]
                for key in teachers
            )
        ]

    def _request(
        self,
        pupil: Pupil,
        need: str,
        discipline: str | None,
        teachable: list[str],
    ) -> tuple[int | None, int | None, str | None]:
        if need in self.services:
            return None, None, need

        ministry = self.ministry[(pupil.level, need)]
        name = discipline or self.rng.choice(teachable)

        # Now and then a discipline asked on its own, outside any ministry subject.
        if discipline is None and self.rng.random() < 0.12:
            return None, self.disciplines[name].id, None

        return ministry.id, self.disciplines[name].id, None

    # Families ask for what the association teaches that day; requests carry
    # (need, discipline, minutes, disciplines teachable then).
    def _week_requests(
        self,
        pupil: Pupil,
        slot: Slot,
        present: dict[str, list[Availability]],
    ) -> list[tuple[str, str | None, int, list[str]]]:
        _, mode, start, end, fixed = slot
        teachers = self._within_reach(pupil, present, mode, _clock(start), _clock(end))

        if fixed:
            requests = []

            for need, discipline, minutes in fixed:
                teachable = self._taught_by(pupil, need, teachers)

                if not teachable:
                    continue

                requests.append((need, discipline, minutes, teachable))

            return requests

        length = minutes_between(_clock(start), _clock(end))
        splits = {
            60: [[60]],
            90: [[90], [60], [60]],
            120: [[60, 60], [60, 60], [120], [90]],
            150: [[90, 60], [60, 60], [90]],
            180: [[90, 90], [60, 60], [120, 60]],
        }.get(length, [[min(length, 120)]])
        durations = self.rng.choice(splits)
        available = {
            name: (weight, teachable)
            for name, weight in pupil.needs
            if (teachable := self._taught_by(pupil, name, teachers))
        }
        requests = []

        for minutes in durations:
            asked = {row[0] for row in requests}
            names = [name for name in available if name not in asked]

            if not names:
                break

            weights = [available[name][0] for name in names]
            name = self.rng.choices(names, weights)[0]
            requests.append((name, None, minutes, available[name][1]))

        return requests

    def _booking(
        self,
        presence: Presence,
        request: tuple[int | None, int | None, str | None],
        minutes: int,
        pupil: Pupil,
    ) -> Booking:
        ministry_id, discipline_id, service = request
        tags: list[BookingTagEnum] = []
        topic = None
        notes = None

        if service is None:
            discipline = self._discipline_name(discipline_id)

            if self.rng.random() < 0.6:
                tags.append(
                    self.rng.choice(
                        [
                            BookingTagEnum.HOMEWORK,
                            BookingTagEnum.HOMEWORK,
                            BookingTagEnum.ORAL_TEST,
                            BookingTagEnum.WRITTEN_TEST,
                            BookingTagEnum.STUDY,
                            BookingTagEnum.ENRICHMENT,
                        ],
                    ),
                )

            if self.rng.random() < 0.6:
                topic = self.rng.choice(_TOPICS[discipline])

            if self.rng.random() < 0.1:
                notes = self.rng.choice(_BOOKING_NOTES)

        booking = Booking(
            presence=presence,
            duration=minutes,
            tags=tags,
            topic=topic,
            notes=notes,
            association_subject_id=discipline_id if ministry_id is None else None,
            service_name=service,
        )

        if ministry_id is not None:
            booking.subjects_requested = [
                SubjectRequested(
                    ministry_subject_id=ministry_id,
                    association_subject_id=discipline_id,
                ),
            ]

        for key in pupil.prefers[:3]:
            if self._teacher_can(key, pupil, request):
                teacher = self.teachers[key].tax_code
                booking.preferred_teachers.append(
                    BookingPreferredTeacher(teacher_tax_code=teacher),
                )

        self.session.add(booking)

        return booking

    def _teacher_can(
        self,
        key: str,
        pupil: Pupil,
        request: tuple[int | None, int | None, str | None],
    ) -> bool:
        _, discipline_id, service = request

        if service is not None:
            return service in self.teacher_services[key]

        return (discipline_id, self.programs[pupil.program].id) in self.competences[key]

    async def days(self) -> None:
        admin = self.admins[AdministratorRoleEnum.OTHER]
        day = self.season_start

        while day <= self.window_end:
            if day in self.openings:
                await self._day(day, admin)

            day += timedelta(days=1)

    async def _day(self, day: date, admin: Person) -> None:
        weekday = day.isoweekday()
        future = day > self.today
        availability: dict[str, list[Availability]] = defaultdict(list)

        for key, spec in self.teacher_specs.items():
            for row_weekday, mode, start, end in spec.hours:
                if row_weekday != weekday:
                    continue

                opens = _clock(start)
                # Cut short where the association closes early that day.
                closes = min(
                    (
                        min(_clock(end), row_closes)
                        for row_mode, row_opens, row_closes in self.openings[day]
                        if row_mode == mode and row_opens <= opens < row_closes
                    ),
                    default=None,
                )

                if closes is None or minutes_between(opens, closes) < 60:
                    continue

                if self.rng.random() < (0.03 if spec is _DEMO_TEACHER else 0.08):
                    continue

                row = Availability(
                    teacher_tax_code=self.teachers[key].tax_code,
                    date=day,
                    mode=mode,
                    start_time=opens,
                    end_time=closes,
                )
                self.session.add(row)
                availability[key].append(row)

        planned: list[tuple[Pupil, Presence, list[Placed]]] = []

        for pupil in self.pupils:
            for slot in pupil.slots:
                slot_weekday, mode, start, end, fixed = slot
                opens, closes = _clock(start), _clock(end)

                if slot_weekday != weekday:
                    continue

                if not self._opening_has(day, mode, opens, closes):
                    continue

                attendance = 0.95 if fixed else 0.88

                # Later weeks are still being booked: fewer hours in so far.
                if future:
                    attendance -= 0.15

                if self.rng.random() > attendance:
                    continue

                requests = self._week_requests(pupil, slot, availability)

                if not requests:
                    continue

                booker = pupil.bookers[0]

                if len(pupil.bookers) > 1 and self.rng.random() < 0.3:
                    booker = self.rng.choice(pupil.bookers[1:])

                booked = day - timedelta(days=self.rng.randint(1, 5))
                presence = Presence(
                    date=day,
                    mode=mode,
                    start_time=opens,
                    end_time=closes,
                    student_tax_code=pupil.person.tax_code,
                    booker_tax_code=booker,
                    created_at=self._moment(booked, 21),
                )
                self.session.add(presence)
                placed = []

                for need, discipline, minutes, teachable in requests:
                    request = self._request(pupil, need, discipline, teachable)
                    booking = self._booking(presence, request, minutes, pupil)
                    placed.append(Placed(booking, request, minutes))

                planned.append((pupil, presence, placed))

        await self.session.flush()

        activity = None

        if weekday == 3 and availability.get("garvoli"):
            slot = next(row for row in availability["garvoli"] if row.mode == _PRESENCE)
            activity = CalendarActivity(
                date=day,
                band=TimeBandEnum.AFTERNOON,
                name="Laboratorio di metodo di studio",
                description=(
                    "Per le medie: come organizzare il diario e lo studio a casa."
                ),
                availability=slot,
                teacher_mode=slot.mode,
                start_time=time(17),
                end_time=time(18),
            )
            self.session.add(activity)

        bands = sorted(
            {band_of(presence.start_time) for _, presence, _ in planned}
            | ({TimeBandEnum.AFTERNOON} if activity else set()),
        )
        publishable = [band for band in bands if has_closed(day, band, self.now)]

        if not publishable:
            await self.session.flush()
            return

        taught: dict[str, list[Taught]] = defaultdict(list)
        busy: dict[str, list[tuple[time, time]]] = defaultdict(list)

        if activity is not None:
            busy["garvoli"].append((time(17), time(18)))

        lessons: list[Lesson] = []

        # The demo pupils' fixed hours are planned first, as the reviewers look at them.
        for pupil, presence, placed in sorted(
            planned,
            key=lambda row: (not row[0].fixed, row[1].start_time),
        ):
            band = band_of(presence.start_time)

            if band not in publishable:
                continue

            own: list[tuple[time, time]] = []
            unplaced = []

            # Longest first: short requests fit the gaps the long ones leave.
            for row in sorted(placed, key=lambda item: -item.minutes):
                spot = self._place(
                    pupil,
                    presence,
                    row,
                    own,
                    availability,
                    taught,
                    busy,
                )

                if spot is None:
                    unplaced.append(row.booking)
                    continue

                lesson, start, end = spot

                if lesson not in lessons:
                    lessons.append(lesson)

                own.append((start, end))

            # Nobody free to teach it: the request goes, the presence too if left empty.
            self.dropped += len(unplaced)

            if len(unplaced) == len(placed):
                await self.session.delete(presence)
                continue

            for booking in unplaced:
                await self.session.delete(booking)

        await self.session.flush()
        await self._rooms(day, lessons)
        await self.session.flush()

        for band in publishable:
            band_lessons = [
                lesson for lesson in lessons if band_of(lesson.start_time) == band
            ]

            if not band_lessons and not (activity and band == TimeBandEnum.AFTERNOON):
                continue

            closed = closes_at(day, band)
            delay = timedelta(minutes=self.rng.randint(20, 90))
            published = min(closed + delay, self.now)
            self.session.add(
                CalendarPublication(
                    date=day,
                    band=band,
                    published_at=published,
                    published_by=admin.tax_code,
                ),
            )
            self.published.append((day, band))

        await self.session.flush()

    def _place(
        self,
        pupil: Pupil,
        presence: Presence,
        row: Placed,
        own: list[tuple[time, time]],
        availability: dict[str, list[Availability]],
        taught: dict[str, list[Taught]],
        busy: dict[str, list[tuple[time, time]]],
    ) -> tuple[Lesson, time, time] | None:
        online = presence.mode == _ONLINE
        candidates = [
            key
            for key in availability
            if key not in pupil.avoids and self._teacher_can(key, pupil, row.request)
        ]
        load = {
            key: sum(minutes_between(item.start, item.end) for item in taught[key])
            for key in candidates
        }
        self.rng.shuffle(candidates)
        def rank(key: str) -> tuple[int, int]:
            preferred = pupil.prefers.index(key) if key in pupil.prefers else 99

            return preferred, load[key]

        candidates.sort(key=rank)
        start = presence.start_time

        while minutes_between(start, presence.end_time) >= row.minutes:
            end = _shift(start, row.minutes)

            # A pupil cannot sit two lessons at once.
            if any(begin < end and start < finish for begin, finish in own):
                start = _shift(start, 15)
                continue

            for key in candidates:
                slot = self._slot(availability[key], presence.mode, start, end)

                if slot is None:
                    continue

                if not self._free(key, start, end, online, taught, busy):
                    continue

                _, discipline_id, service = row.request
                joinable = next(
                    (
                        item
                        for item in taught[key]
                        if item.start == start
                        and item.end == end
                        and not item.online
                        and not online
                        and item.students == 1
                        and item.discipline is not None
                        and item.discipline == discipline_id
                    ),
                    None,
                )

                if joinable is not None and self.rng.random() < 0.6:
                    joinable.lesson.lesson_bookings.append(
                        LessonBooking(booking=row.booking),
                    )
                    joinable.students = 2
                    return joinable.lesson, start, end

                lesson = Lesson(
                    availability=slot,
                    date=presence.date,
                    teacher_mode=slot.mode,
                    mode=presence.mode,
                    start_time=start,
                    end_time=end,
                )
                lesson.lesson_bookings.append(LessonBooking(booking=row.booking))

                if discipline_id is not None:
                    lesson.lesson_disciplines.append(
                        LessonDiscipline(association_subject_id=discipline_id),
                    )

                self.session.add(lesson)
                taught[key].append(
                    Taught(lesson, start, end, online, 1, discipline_id, service),
                )

                if presence.date < self.today:
                    self.past_lessons.append(
                        (lesson, pupil.person, key, self._label(row)),
                    )

                return lesson, start, end

            start = _shift(start, 15)

        return None

    def _label(self, row: Placed) -> str:
        ministry_id, discipline_id, service = row.request

        if service is not None:
            return service

        return self._discipline_name(discipline_id)

    def _discipline_name(self, discipline_id: int | None) -> str:
        return next(
            name for name, row in self.disciplines.items() if row.id == discipline_id
        )

    @staticmethod
    def _slot(
        rows: Sequence[Availability],
        mode: str,
        start: time,
        end: time,
    ) -> Availability | None:
        fitting = [
            row for row in rows if row.start_time <= start and end <= row.end_time
        ]
        same = [row for row in fitting if row.mode == mode]

        if same:
            return same[0]

        # A teacher in the building may follow a pupil at home, never the other way.
        if mode == _ONLINE:
            return next((row for row in fitting if row.mode == _PRESENCE), None)

        return None

    @staticmethod
    def _free(
        key: str,
        start: time,
        end: time,
        online: bool,
        taught: dict[str, list[Taught]],
        busy: dict[str, list[tuple[time, time]]],
    ) -> bool:
        if any(begin < end and start < finish for begin, finish in busy[key]):
            return False

        overlapping = [
            item for item in taught[key] if item.start < end and start < item.end
        ]

        if not overlapping:
            return True

        if online or any(item.online for item in overlapping):
            return False

        return sum(item.students for item in overlapping) + 1 <= MAX_CONCURRENT_STUDENTS

    async def _rooms(self, day: date, lessons: list[Lesson]) -> None:
        in_building = sorted(
            {
                lesson.availability.teacher_tax_code
                for lesson in lessons
                if lesson.teacher_mode == _PRESENCE
            },
        )

        if not in_building:
            return

        assignments = []

        for index, code in enumerate(in_building):
            assignment = TeacherRoomAssignment(
                date=day,
                teacher_tax_code=code,
                start_time=MIDNIGHT,
                room_id=self.rooms[index % len(self.rooms)].id,
            )
            self.session.add(assignment)
            assignments.append(assignment)

        await self.session.flush()
        supervisions: list[RoomSupervision] = []

        for room in self.rooms:
            members = [
                row.teacher_tax_code for row in assignments if row.room_id == room.id
            ]
            hours = {
                code: [
                    lesson
                    for lesson in lessons
                    if lesson.teacher_mode == _PRESENCE
                    and lesson.availability.teacher_tax_code == code
                ]
                for code in members
            }
            minutes = {
                code: sum(
                    minutes_between(lesson.start_time, lesson.end_time)
                    for lesson in hours[code]
                )
                for code in members
            }
            members.sort(key=minutes.__getitem__, reverse=True)

            for code in members:
                if room.id not in rooms_left_open(lessons, assignments, supervisions):
                    break

                shift = RoomSupervision(
                    date=day,
                    teacher_tax_code=code,
                    room_id=room.id,
                    assignment_start=MIDNIGHT,
                    start_time=min(lesson.start_time for lesson in hours[code]),
                    end_time=max(lesson.end_time for lesson in hours[code]),
                )
                self.session.add(shift)
                supervisions.append(shift)

        if teachers_adrift(lessons, assignments) or rooms_left_open(
            lessons,
            assignments,
            supervisions,
        ):
            raise RuntimeError(f"Stanze non sistemate il {day.isoformat()}")

    async def _since(self) -> int:
        latest = select(func.coalesce(func.max(Notification.id), 0))

        return await self.session.scalar(latest)

    async def _dated(self, since: int, moment: datetime) -> list[int]:
        query = select(Notification.id).where(Notification.id > since)
        rows = list(await self.session.scalars(query))

        if rows:
            await self.session.execute(
                update(Notification)
                .where(Notification.id.in_(rows))
                .values(created_at=moment),
            )

        return rows

    async def notes(self) -> None:
        admin = self.admins[AdministratorRoleEnum.OTHER]
        president = self.admins[AdministratorRoleEnum.PRESIDENT]
        by_name = {
            f"{pupil.person.first_name} {pupil.person.last_name}": pupil.person
            for pupil in self.pupils
        }

        technical = (
            (
                "Pietro Ferragin",
                "Per **inglese** usare le schede semplificate nella cartella della "
                "segreteria. La verifica di grammatica è a fine mese.",
            ),
            (
                "Giada Ferragin",
                "**Matematica**: ripassare le tabelline prima di passare alle "
                "divisioni in colonna.",
            ),
            (
                "Nicola Rastelin",
                "Debito formativo in **economia aziendale** dall'anno scorso: "
                "ripartire dalla partita doppia.",
            ),
            (
                "Martina Salmavori",
                "Prepara la certificazione **DELF B1** di francese a maggio.",
            ),
        )

        for name, message in technical:
            self.session.add(
                TechnicalNote(
                    student_tax_code=by_name[name].tax_code,
                    author_tax_code=admin.tax_code,
                    text=message,
                    created_at=self._moment(self.season_start + timedelta(days=3)),
                ),
            )

        methodological = (
            (
                "Pietro Ferragin",
                "Certificazione di **dislessia e disortografia**.\n\n"
                "- Concedere tempi più lunghi per la lettura.\n"
                "- Preferire mappe concettuali e schemi colorati.\n"
                "- Leggere ad alta voce le consegne degli esercizi.",
            ),
            (
                "Lorenzo Scarsellini",
                "- Lezioni brevi, con una pausa ogni venti minuti.\n"
                "- Una consegna alla volta, scritta sul quaderno.\n"
                "- Riscontro immediato su ogni esercizio svolto.",
            ),
            (
                "Aurora Tessarolin",
                "Fatica nella comprensione dei testi lunghi: dividerli in "
                "paragrafi e farle riassumere ognuno a voce.",
            ),
        )

        for name, message in methodological:
            self.session.add(
                MethodologicalNote(
                    student_tax_code=by_name[name].tax_code,
                    author_tax_code=self.psychologist.tax_code,
                    text=message,
                    created_at=self._moment(self.season_start + timedelta(days=8)),
                ),
            )

        administrator_notes = (
            (
                "campiverdi",
                "Grazie per la disponibilità del mercoledì: le famiglie delle medie "
                "l'hanno molto apprezzata.",
                4,
            ),
            (
                "casolini",
                "Ricordati di firmare il registro delle ore **PCTO** in segreteria "
                "entro la fine del mese.",
                12,
            ),
        )

        for key, message, days_ago in administrator_notes:
            note = AdministratorNote(
                teacher_tax_code=self.teachers[key].tax_code,
                author_tax_code=president.tax_code,
                text=message,
                created_at=self.now - timedelta(days=days_ago, hours=3),
            )
            self.session.add(note)
            since = await self._since()
            await announce_administrator_note(self.session, note)
            await self._dated(since, note.created_at)

        lessons = sorted(self.past_lessons, key=lambda row: row[0].date)
        own = [row for row in lessons if row[2] == _DEMO_TEACHER.key][-2:]
        picks = own + self.rng.sample(
            lessons,
            min(6, len(lessons)),
        )

        for lesson, pupil, key, subject in picks:
            topics = _TOPICS.get(subject, ("gli argomenti della settimana",))
            topic = self.rng.choice(topics)
            note = TeacherNote(
                student_tax_code=pupil.tax_code,
                author_tax_code=self.teachers[key].tax_code,
                lesson_id=lesson.id,
                lesson_date=lesson.date,
                subject=subject,
                text=self.rng.choice(_TEACHER_NOTES).format(topic=topic.lower()),
                created_at=_at(lesson.date, lesson.end_time) + timedelta(minutes=10),
            )
            self.session.add(note)
            since = await self._since()
            await announce_teacher_note(self.session, note)
            await self._dated(since, note.created_at)

        await self.session.flush()

    async def notices(self) -> None:
        president = self.admins[AdministratorRoleEnum.PRESIDENT]
        secretary = self.admins[AdministratorRoleEnum.OTHER]
        start = self.season_start
        christmas = date(self.school_year, 12, 24)
        epiphany = date(self.school_year + 1, 1, 6)
        meeting = self.meeting_day
        member, parent = NoticeRoleEnum.MEMBER, NoticeRoleEnum.PARENT
        notices = (
            (
                president,
                "Benvenuti nel nuovo anno associativo!",
                f"Care famiglie, cari soci,\n\nda **{_long_date(start)}** riprendono "
                "le attività di Casa Michela. Siamo aperti dal lunedì al venerdì "
                "dalle 14:30 alle 18:30, il sabato mattina dalle 9:00 alle 12:30; "
                "le lezioni online anche la sera.\n\n"
                "Le prenotazioni della settimana seguente si aprono **ogni venerdì "
                "alle 20:00** dall'app.\n\nBuon anno a tutti!",
                [member, parent],
                start - timedelta(days=4),
                True,
                None,
            ),
            (
                secretary,
                "Riunione di inizio anno per i docenti",
                f"La riunione si terrà **{_long_date(start - timedelta(days=3))} alle "
                "18:00** in Biblioteca: presentazione dei nuovi iscritti e delle "
                "regole per le stanze.",
                [NoticeRoleEnum.TEACHER, NoticeRoleEnum.PSYCHOLOGIST],
                start - timedelta(days=7),
                False,
                None,
            ),
            (
                secretary,
                "Laboratorio di metodo di studio del mercoledì",
                "Ogni **mercoledì dalle 17:00 alle 18:00** Valentina accompagna i "
                "ragazzi delle medie nell'organizzare il diario e lo studio a casa. "
                "Non serve prenotare: basta essere in sede.",
                [parent, NoticeRoleEnum.STUDENT],
                start + timedelta(days=6),
                False,
                None,
            ),
            (
                president,
                "Assemblea dei soci",
                "L'assemblea ordinaria dei soci è convocata per "
                f"**{_long_date(meeting)} alle 17:30** nella sede dell'associazione. "
                "Quel giorno le lezioni in presenza terminano alle 17:00.\n\n"
                "In allegato la convocazione con l'ordine del giorno.",
                [member, parent],
                self.today - timedelta(days=5),
                False,
                (
                    "Convocazione assemblea dei soci.pdf",
                    [
                        "Associazione Casa Michela",
                        "",
                        "Convocazione dell'assemblea ordinaria dei soci",
                        f"{_long_date(meeting).capitalize()}, ore 17:30",
                        "",
                        "Ordine del giorno:",
                        "1. Relazione della presidente sull'anno trascorso",
                        "2. Approvazione del rendiconto",
                        "3. Programma delle attività",
                        "4. Varie ed eventuali",
                    ],
                ),
            ),
            (
                secretary,
                "Chiusura per le vacanze di Natale",
                f"L'associazione resterà chiusa da **{_long_date(christmas)}** a "
                f"**{_long_date(epiphany)}** compresi. Le attività riprendono "
                f"{_long_date(epiphany + timedelta(days=1))}.",
                [member, parent],
                self.today - timedelta(days=1),
                False,
                None,
            ),
        )

        for author, title, message, recipients, day, pinned, attachment in notices:
            if day > self.today:
                continue

            created = self._moment(day, 18)
            notice = Notice(
                author_tax_code=author.tax_code,
                title=title,
                message=message,
                recipients=recipients,
                recipient_count=0,
                created_at=created,
                updated_at=created,
            )

            if attachment is not None:
                file_name, lines = attachment
                content = _pdf(lines)
                notice.files.append(
                    NoticeFile(
                        file_name=file_name,
                        content_type="application/pdf",
                        size=len(content),
                        content=content,
                    ),
                )

            if pinned:
                notice.pin = NoticePin(
                    pinned_by_tax_code=author.tax_code,
                    pinned_at=created,
                )

            self.session.add(notice)
            await self.session.flush()
            since = await self._since()
            await announce_notice(self.session, notice)
            notice.recipient_count = len(await self._dated(since, created))

        await self.session.flush()

    async def reports(self) -> None:
        by_name = {
            f"{person.first_name} {person.last_name}": person
            for person in self.people.values()
        }
        secretary = self.admins[AdministratorRoleEnum.OTHER]
        reports = (
            (
                "Elena Zandrelli",
                "PARENT",
                ReportKindEnum.APP_PROBLEM,
                {
                    "description": "Dal telefono non riesco ad aprire il calendario di "
                    "Alice: la pagina resta bianca. Dal computer invece funziona.",
                },
                3,
                False,
            ),
            (
                "Federico Gambrasi",
                "TEACHER",
                ReportKindEnum.MISSING_SUBJECT,
                {
                    "title": "Test d'ingresso universitari",
                    "description": "Alcuni ragazzi di quinta chiedono aiuto per i "
                    "test di medicina e di ingegneria.",
                },
                6,
                False,
            ),
            (
                "Roberta Salmavori",
                "PARENT",
                ReportKindEnum.PERSONAL_DATA,
                {
                    "person_tax_code": by_name["Martina Salmavori"].tax_code,
                    "corrections": [
                        ("Indirizzo di residenza", "Via Trieste 14, Sarcedo"),
                    ],
                },
                9,
                True,
            ),
        )

        for name, role, kind, fields, days_ago, resolved in reports:
            moment = self.now - timedelta(days=days_ago, hours=2)
            since = await self._since()
            report, _ = await record_report(
                self.session,
                by_name[name],
                role,
                kind,
                **fields,
            )
            report.created_at = moment
            await self._dated(since, moment)

            if resolved:
                await resolve_report(self.session, report, secretary.tax_code)
                report.resolved_at = moment + timedelta(hours=20)

        await self.session.flush()

    async def announcements(self) -> None:
        recent = [
            (day, band)
            for day, band in self.published
            if day >= self.today - timedelta(days=2)
        ]

        for day, band in recent:
            since = await self._since()
            await announce_publication(self.session, day, band)
            moment = min(closes_at(day, band) + timedelta(minutes=45), self.now)
            await self._dated(since, moment)

        # Older news has been seen: only the last two days stay unread.
        await self.session.execute(
            update(Notification)
            .where(Notification.created_at < self.now - timedelta(days=2))
            .values(read_at=Notification.created_at + timedelta(hours=3)),
        )


async def _wipe(session: AsyncSession, keep: Sequence[str]) -> set[str]:
    found = dict(
        (
            await session.execute(
                select(Account.username, Account.tax_code).where(
                    Account.username.in_(keep),
                ),
            )
        ).all(),
    )
    missing = sorted(set(keep) - set(found))

    if missing:
        raise SystemExit(f"Account da tenere non trovati: {', '.join(missing)}")

    codes = list(found.values())

    for table, column in _KEPT_ROWS:
        await session.execute(
            text(
                f"CREATE TEMP TABLE kept_{table} ON COMMIT DROP AS "
                f"SELECT * FROM {table} WHERE {column} = ANY(:codes)",
            ),
            {"codes": codes},
        )

    tables = ", ".join(table.name for table in Base.metadata.sorted_tables)
    await session.execute(text(f"TRUNCATE {tables} RESTART IDENTITY CASCADE"))

    for table, _ in _KEPT_ROWS:
        await session.execute(text(f"INSERT INTO {table} SELECT * FROM kept_{table}"))
        sequence = await session.scalar(
            text(
                "SELECT pg_get_serial_sequence(:table, 'id') "
                "FROM information_schema.columns "
                "WHERE table_name = :table AND column_name = 'id'",
            ),
            {"table": table},
        )

        # Kept rows keep their ids: the sequence starts past them.
        if sequence is not None:
            await session.execute(
                text(
                    f"SELECT setval(:sequence, "
                    f"(SELECT coalesce(max(id), 0) + 1 FROM {table}), false)",
                ),
                {"sequence": sequence},
            )

    return set(codes)


async def main(catalogue: str, keep: Sequence[str]) -> None:
    password = os.environ.get(_PASSWORD_VARIABLE, "")

    if not password:
        raise SystemExit(f"Manca {_PASSWORD_VARIABLE}: la password dell'account demo.")

    with open(catalogue, encoding="utf-8") as handle:
        rows = json.load(handle)

    async with AsyncSessionLocal() as session:
        kept = await _wipe(session, keep)
        seeder = Seeder(session, now_in_rome(), password, kept, rows)
        await seeder.catalogues()
        await seeder.opening_hours()
        await seeder.board()
        await seeder.staff_room()
        await seeder.families()
        await seeder.others()
        await seeder.days()
        await seeder.notes()
        await seeder.notices()
        await seeder.reports()
        await seeder.announcements()
        await session.commit()

        counts = {
            "persone": Person,
            "prenotazioni": Booking,
            "lezioni": Lesson,
            "calendari pubblicati": CalendarPublication,
            "notifiche": Notification,
        }

        for label, model in counts.items():
            total = await session.scalar(select(func.count()).select_from(model))
            print(f"{label}: {total}")

    print(f"richieste senza docente, tolte: {seeder.dropped}")
    print(f"Account demo: {_DEMO_USERNAME}")


def _parse() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Associazione fittizia per le demo")
    parser.add_argument(
        "--catalog",
        required=True,
        help="JSON con discipline, materie, percorsi e scuole da copiare.",
    )
    parser.add_argument(
        "--keep",
        action="append",
        default=[],
        help="Nome utente da conservare (ripetibile).",
    )

    return parser.parse_args()


if __name__ == "__main__":
    arguments = _parse()

    try:
        asyncio.run(main(arguments.catalog, arguments.keep))
    except ValueError as err:
        print(f"Errore: {err}", file=sys.stderr)
        raise SystemExit(1) from err
