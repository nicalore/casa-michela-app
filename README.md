<p align="center">
  <img src="https://github.com/user-attachments/assets/d1f20e4e-2c6a-4798-9036-2507a76d98a6" width="300"/>
</p>

# Casa Michela Application

Web platform for managing the activities of [Associazione Casa Michela](https://www.casamichela.it) (Thiene, Italy), a non-profit organization providing after-school tutoring, educational support, and psychological services to students of all ages.

## OVERVIEW

The project aims to develop a unified web application to support the organizational and administrative activities of the association.

Currently, most operations are handled manually through informal tools such as messaging apps and spreadsheets. This approach leads to inefficiencies, increased risk of errors, and difficulties in managing and accessing data.

The application introduces a centralized system to manage all aspects of the association in a structured and efficient way, improving coordination between users and reducing manual workload.

## FEATURES

* Lesson booking system for parents
* Teacher availability management
* Automatic lesson scheduling based on bookings and teacher availability, with daily calendar generation
* Payment tracking and management
* Teacher workload and salary tracking
* Role-based access control
* Psychological session management
* Course booking system (evening classes)

## PROJECT STATUS & ROADMAP

**Implemented**
* Identity and access management
* Booking and availability system (Teachers, Parents, Administrators)

**In progress**
* Scheduling algorithm and calendar management

**Planned**
* Payment and salary system
* Advanced features (courses, psychologists, document management)

## USER ROLES

The system supports multiple user roles, each with specific functionalities:

* **Parents** – book lessons, manage reservations, view payments
* **Students** – view scheduled lessons
* **Teachers** – provide availability, view schedule, track work hours
* **Psychologists** – manage sessions and methodological notes
* **Course Participants** – book and manage courses
* **Administrators** – manage users, bookings, scheduling, and payments

## ARCHITECTURE

The system follows a client-server architecture:

* **Frontend**: Flutter (Dart)
* **Backend**: FastAPI (Python)
* **Database**: PostgreSQL
* **API**: RESTful services

The application is designed with a modular structure, including:

* Identity and Access Management
* Booking and Availability Management
* Scheduling System
* Administrative and Financial Management
* Clinical/Educational Support Module
* Notification Service
* Logging System

## DEPLOYMENT

The system will be accessible via a dedicated subdomain: `app.casamichela.it`.
Deployment will be handled through AWS cloud infrastructure.

## LICENSE

This project is **source-available**.
The source code is publicly accessible for viewing purposes only. Reuse, modification, or redistribution is not permitted without explicit authorization from the author.
See the [LICENSE.md](LICENSE.md) file for full details.

## AUTHOR

**Nicolò Calore**
Developed for Associazione Casa Michela
