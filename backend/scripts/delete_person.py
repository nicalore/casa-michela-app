import asyncio
import os
import sys

# Ensure the backend directory is in the path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from app.db.session import engine 
from app.models.person import Person

async def delete_person_data(tax_code: str):
    async_session = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
    
    async with async_session() as db:
        # 1. Fetch only the basic Person info to show the prompt and get the image
        person = await db.get(Person, tax_code)
        
        if not person:
            print(f"\nError: No person found with tax code '{tax_code}'.")
            return

        print(f"\nPERSON FOUND:")
        print(f"Name: {person.first_name} {person.last_name}")
        print(f"Tax Code: {person.tax_code}")
        
        confirm = input("\nWARNING: Are you sure you want to delete this person and ALL related data? (type 'YES' to confirm): ").strip().upper()
        
        if confirm != 'YES':
            print("\nOperation cancelled. No data has been deleted.")
            return

        try:
            # 2. Delete physical profile image if it exists
            if person.profile_image_url:
                file_path = person.profile_image_url.lstrip("/")
                if os.path.exists(file_path):
                    os.remove(file_path)
                    print(f"Physical profile image deleted: {file_path}")

            # 3. Direct SQL Delete
            # Bypassing the Python ORM completely and letting PostgreSQL handle the CASCADE
            stmt = delete(Person).where(Person.tax_code == tax_code)
            await db.execute(stmt)
            await db.commit()
            
            print(f"\nSUCCESS: Person {person.tax_code} and all related profiles have been deleted.")
            
        except Exception as e:
            await db.rollback()
            print(f"\nError: A critical error occurred during deletion:")
            print(str(e))

def main():
    print("========================================")
    print("      PERSON DELETION SCRIPT            ")
    print("========================================")
    
    tax_code = input("Enter the Tax Code to delete: ").strip().upper()
    
    if len(tax_code) != 16:
        print("\nError: Invalid format. Tax code must be 16 characters long.")
        return
        
    asyncio.run(delete_person_data(tax_code))

if __name__ == "__main__":
    main()