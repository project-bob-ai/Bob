**Quick Summary:** I gave IBM Bob a single detailed prompt describing a complete Student Admission Management System for IBM i. Using IBM i Developer Mode, powered by Premium Package for i (PPI), IBM Bob planned the application, generated the IBM i backend, handled compilation and database setup, and built the web interface using Python Flask, HTML, CSS, and JavaScript in a single development session. What makes this story interesting is not just what got built, but how IBM Bob worked through the real IBM i platform constraints that came up along the way.


## The Goal: A Full-Stack Admission System on IBM i

The application I had in mind was a Student Admission Management System. I wanted to build it as a complete application on IBM i, with Db2 for i and RPGLE handling the backend, Python Flask providing the REST API, and HTML, CSS, and JavaScript providing the browser interface.

I also wanted the application to include the kinds of features you would expect in a real admission system, such as adding and updating students, filtering and sorting records, pagination, soft-delete, and CSV export.

The web layer would connect to Db2 for i using the ibm_db_dbi Python driver. I wanted to see how IBM Bob would put all these pieces together and handle the IBM i-specific issues that came up during development.

## IBM Bob Premium Package for i Why This Works


Before getting into the development, it is worth explaining what made this application possible. The IBM i capabilities I used throughout the application came from Premium Package for i (PPI).

With IBM i Developer Mode active, IBM Bob could work directly with my IBM i environment through Code for IBM i. It was not just generating code for me to copy and run later. IBM Bob could create source members, execute CL commands, run SQL against Db2 for i, read compiler output, work with IFS files, and check the results directly on the system.

With IBM i Developer Mode active, IBM Bob can:

Create and update QSYS source members directly on the IBM i using write_member
Execute CL commands such as CRTSRCPF, ADDPFM, CRTSQLRPGI, CRTSRVPGM, CRTBNDDIR, CRTJRN, and STRJRNPF
Run SQL statements against QSYS2 SQL Services to verify objects, query table schemas, and check index definitions
Execute PASE shell commands to write IFS files, run Python scripts, and verify directory structures
Read compiler output and job log messages to diagnose build failures
Apply IBM i Skills that encode platform-specific knowledge about module compilation sequences, binder source case sensitivity rules, CCSID constraints, journaling requirements, and Db2 for i SQL syntax
Without PPI, this would be a text generation exercise. With PPI, IBM Bob becomes a development partner that actually executes the work, catches the errors, and resolves them using knowledge of IBM i internals.


### The Prompt: One Detailed Message

I gave IBM Bob a single detailed prompt with the requirements for the entire application. I described the database schema, RPGLE architecture, Python Flask layer, IFS directory structure, and compilation requirements all in one message.

I also made a few IBM i-specific requirements clear. The SCHADMLIB library already existed on the system, so IBM Bob should not recreate it. All RPGLE and SQLRPGLE source had to be created as QSYS source members inside SCHADMLIB. I also specified that the RPGLE /copy directives should use QSYS member syntax rather than IFS paths.

[Screenshot: The full prompt submitted to IBM Bob in IBM i Developer Mode]

I was curious to see what IBM Bob would do with a prompt this long. Would it ask me to break the work into smaller pieces? Would it start with the database and wait for the next instruction?

It did neither.

IBM Bob first activated five IBM i Skills and then created a structured plan for the application. I will come back to that plan in the next section because it was interesting to see how IBM Bob broke the work into separate phases.


### The Build Plan: IBM Bob's 16-Phase Approach

Before starting the build, IBM Bob first checked the current state of SCHADMLIB using the QSYS2.OBJECT_STATISTICS SQL Service. It confirmed that the library was empty and then created a structured plan for the application.

[Screenshot: IBM Bob's 16-phase todo list in IBM i Developer Mode]

The structured 16-phase implementation plan generated before any source was written.

What I liked about the plan was that IBM Bob put the steps in the right order. There were dependencies between several parts of the application, and those dependencies mattered on IBM i.

Source physical files must exist before source members can be written into them
The copybook (STUDINC) must exist before any SQLRPGLE module can be compiled, because all four modules reference it via /copy SCHADMLIB/QRPGLEREF,STUDINC
All four modules must compile successfully before the service program can be created
The service program must exist before it can be added to the binding directory
Tables must be journaled before any Python DML can execute against them
IBM Bob tracked every phase using the update_todo_list tool throughout the session, marking items complete as each phase succeeded and keeping the remaining work visible. It is a small detail, but it meant the entire build state was always clear.

### IBM i Skills: What IBM Bob Selected and Why

One of the things I wanted to understand during this build was how IBM Bob would use the IBM i Skills provided through Premium Package for i (PPI).

IBM i Skills provide IBM i-specific knowledge that IBM Bob can use when working on a particular task. For this application, IBM Bob activated five Skills before generating the backend source:

Skill Activated	Used For
rpg-primer-basics	Foundational IBM i RPG conventions — ctl-opt options, date formats, option flags
rpg-ile-understanding	ILE concepts — module/service program architecture, activation groups, binding directories
rpg-free-format-fundamentals	Fully free-format **free syntax, dcl-proc/end-proc, dcl-pi/end-pi
rpg-procedures-functions	Exported procedure definitions, return types, likeds parameters, const qualifiers
rpg-embedded-sql	SQLSTATE checking, GET DIAGNOSTICS ROW_COUNT, host variables, EXEC SQL in free-format RPG


Five IBM i Skills activated before the backend source was generated.

I found the combination interesting. IBM Bob did not just load the RPG Skills. It also activated the embedded SQL Skill because the backend used SQLRPGLE modules. It also needed the ILE and procedure Skills because those modules would eventually become part of a service program.

That gave me a good indication that IBM Bob was looking at the application as a whole and selecting the IBM i knowledge it needed before starting the actual code generation.


### Phase 1: QSYS Setup and IFS Directory Structure

The first step was setting up the places where the application source would live. IBM Bob created four source physical files in SCHADMLIB using the CRTSRCPF CL command.

These source physical files had different roles. QRPGLESRC was for the RPGLE and SQLRPGLE source members, QRPGLEREF was for the copybook, QSRVSRC was for the service program binder source, and QBNDSRC was for the binding directory definition.

IBM Bob then created the IFS directory structure for the web application using a single PASE shell command:

At this point, the application had two separate areas on IBM i. SCHADMLIB in QSYS was being used for the IBM i source and objects, while /STUADMAPP on the IFS was used for the Python, HTML, CSS, JavaScript, and SQL files.

I liked this separation because it made the structure of the application clear from the beginning. The IBM i source stayed in QSYS, while the web and open-system files stayed on the IFS.


## Phase 2: The Database Layer and a Real DDL Challenge

The database design was more than just creating a table. The STUDENTS table needed an identity column for the student ID, validation rules for the pincode and contact number, a status field defaulting to A, and timestamps for tracking changes. I also needed a separate audit table to record changes to student records.

IBM Bob created the DDL script in /STUADMAPP/QSQLSRC/STUADM_DDL.sql and started executing it.



## Phases 3–8: The RPGLE Backend
The Shared Copybook: STUDINC

Before writing the modules, IBM Bob created the shared copybook in SCHADMLIB/QRPGLEREF as member STUDINC.

The copybook became the common definition used across the backend. It contains the StudDS data structure, which maps the 17 columns from the STUDENTS table to RPG variables. It also defines the ResultDS return structure, constants for return codes and audit operation types, and the prototypes for the exported procedures.

Every module uses:

/copy SCHADMLIB/QRPGLEREF,STUDINC

This was one of the requirements I had included in the original prompt. IBM Bob followed it consistently across all four modules instead of using IFS paths.

[Screenshot: STUDINC copybook member in SCHADMLIB/QRPGLEREF]

The shared copybook containing StudDS, ResultDS, constants, and procedure prototypes.

The ResultDS Pattern: Consistent Error Handling

Every exported procedure returns a ResultDS data structure. I liked this approach because the calling program does not have to handle SQL errors differently for every procedure. It can simply check result.ReturnCode.

The module handles the SQL error checking internally and fills the result with a readable message along with the SQLCODE and SQLSTATE. This gives the application a consistent way to understand whether an operation succeeded or failed.


The soft-delete pattern in STUDELETE is worth highlighting because IBM Bob used a simple two-step approach. First, it checks whether the student exists and is still active:

SELECT STUD_NAME INTO :studName
FROM STUDENTS
WHERE STUDENT_ID = :pStudentId
  AND STATUS = 'A'

If this returns SQLCODE = +100, meaning the student was not found or is already inactive, the procedure returns RC_NOTFOUND without changing the data.

Only after confirming that the student is active does it update the status. The audit entry then captures the student's name before the record becomes inactive.



## Phase 9: Compilation: All Four Modules at Severity 00

With all the source members in place and the binder source corrected, IBM Bob compiled each module using CRTSQLRPGI with OBJTYPE(*MODULE).

One parameter that was important here was DFTRDBCOL(SCHADMLIB). It tells the SQL precompiler to use SCHADMLIB as the default collection for unqualified SQL table references. This means that when the RPGLE source uses FROM STUDENTS, the SQL precompiler resolves it to SCHADMLIB.STUDENTS during compilation.

##  10: Service Program and Binding Directory

With all four modules compiled, IBM Bob created the STUDSRVP service program and bound the four modules together.

The service program exposes eight procedures: ADDSTUDENT, GETSTUDENT, GETSTUDENTS, UPDATESTUDENT, DELETESTUDENT, VALIDATEPINCODE, VALIDATECONTACT, and WRITEAUDIT.

The binder source uses the signature string STUADM_V1R0M0 as the versioning hook. If I add new procedures in the future, they can be added at the end of the binder source while keeping the existing interface compatible with programs that are already using the service program.


The ACTGRP(*CALLER) setting means the service program runs in its caller's activation group rather than creating its own. For this application, where the service program is called from Python via a SQL stored procedure or directly via XMLSERVICE, this is the right setting. It avoids creating unnecessary activation groups and keeps resource management straightforward.

The Journaling Issue: A Classic IBM i Gotcha

After the database tables were created and the RPGLE backend was compiled, IBM Bob tried to insert sample data using the Python ibm_db_dbi driver. The first INSERT failed with SQL7008, indicating that the file was not journaled for commitment control.

This is one of those issues that can catch developers who are new to Db2 for i. When you connect through ODBC or ibm_db_dbi, the driver typically uses connection-level commitment control. Db2 for i requires tables to be enrolled in a journal before they can participate in committed transactions. Tables created through DDL exist in the database, but they are not automatically journaled. They need to be enrolled explicitly.

IBM Bob first checked whether a journal already existed in SCHADMLIB using WRKOBJ OBJ(SCHADMLIB/*ALL) OBJTYPE(*JRN). There was none. It then created the journal infrastructure step by step:



## The Python Driver Numeric Parameter Issue

After journaling was in place, IBM Bob loaded 10 sample students using the Python ibm_db_dbi driver. Seven were inserted successfully on the first attempt, but three failed.

The error was not related to a CHECK constraint. The pincode and contact values were valid. The root cause was a Python driver behavior specific to this IBM i environment.

When passing large integer values, specifically CONTACT_NO = 9876543210, through Python's ? parameterized query binding, the ibm_db_dbi driver failed to map the Python int value to NUMERIC(10,0). The same values worked correctly when they were passed as literal strings.



## Phases 11–14: The Python Flask Web Application

The _validate_student helper function in app.py follows the same validation logic as the RPGLE backend. It checks the pincode range, contact number range, and date format in the same way.

The validation happens at multiple levels by design. Client-side JavaScript catches format errors before the request is sent. Server-side Python validates the data again before it reaches the database. Finally, the database CHECK constraints provide another level of protection.

This means a record that violates the database constraints cannot be inserted, regardless of how the request was created.



The db.py Connection Helper

The database connection uses ibm_db_dbi.connect() with no arguments. This is the same local connection pattern that worked reliably during the DDL execution.

The fetchall_dict helper converts the cursor rows into dictionaries using the column names from cursor.description. This makes it easier for the API endpoints to return the database results as JSON.

HTML Templates: One Form, Two Modes

The student_form.html template is shared between the Add and Edit operations. Flask passes a MODE value, either add or edit, and for edit operations it also passes the STUDENT_ID.

The JavaScript uses these values to decide which API endpoint to call when the form is submitted. For a new student, it calls POST /api/students. For an existing student, it calls PUT /api/students/<id>.

I liked this approach because there is only one form to maintain instead of having two almost identical templates.


JavaScript: Real-Time Validation and CSV Export

The student_form.js file handles the form validation using a FIELDS definition map that describes each field's type and constraints. The validation checks required fields, age range, date format, pincode using /^\d{7}$/, and contact number using /^\d{10}$/.

When a validation error occurs, an error message is shown next to the field without reloading the page.

The student list page uses students_list.js for client-side column sorting, building filter parameters with URLSearchParams, and CSV export. The CSV file is generated directly in the browser from the current page's data, so the export does not require another request to the server.



## What made possible 

Every IBM i capability used in this build came through the Premium Package for i (PPI). That included creating QSYS source members, executing CL commands, running SQL against QSYS2 SQL Services to verify objects, writing files to the IFS through PASE, reading compiler output to diagnose failures, and using IBM i Skills for SQLRPGLE, binder source, CCSID, journaling, and Db2 for i DDL.

Without PPI, this would have been mainly a code generation exercise. With IBM i Developer Mode and Premium Package for i (PPI), IBM Bob worked as a development partner that could build, compile, validate, troubleshoot, and verify the application directly on the IBM i system.

