      *================================================================*
      * STUDRPT  - Student Information Report
      *----------------------------------------------------------------*
      * This program reads the student physical file (STUDENP) and
      * prints a program-described printer file report showing all
      * student information with headings, detail lines, and an
      * end-of-report line.
      *================================================================*
     FSTUDENP   IF   E             DISK
     FSTUDRPTR  O    F  132        PRINTER OFLIND(*INOF)
      *----------------------------------------------------------------*
     D PageCnt         S              3S 0 INZ(0)
      *================================================================*
     C* -----------------------------------------------------------
     C* MAINLINE: Print initial header, then read all student recs
     C* -----------------------------------------------------------
     C                   EXCEPT    HEAD
     C                   READ      STUDENR                                07
     C     *IN07         DOWEQ     '0'
      *
     C   OF              EXCEPT    HEAD
      *
     C                   EXCEPT    DTL
      *
     C                   READ      STUDENR                                07
     C                   ENDDO
      *
     C                   EXCEPT    END
     C                   MOVE      *ON           *INLR
      *================================================================*
     OSTUDRPTR  E            HEAD           1 01
     O                                           10 'Student ID'
     O                                         +  2 'Student Name'
     O                                           55 'Major'
     O                                         +  2 'Grd'
     O                                         +  2 'GPA'
     O                                         +  2 'Enrl Date'
     O                                         +  2 'Birth Date'
     O                                         +  2 'Email'
     O*
     O          E            HEAD           2
     O                                           10 'STUDRPT'
     O                       UDATE         Y   +  2
     O                                          125 'PAGE'
     O                       PAGE          Z    130
     O*
     O          E            HEAD           1
     O                                           10 '----------'
     O                                         +  2 '-------------'
     O                                           55 '--------------'
     O                                         +  2 '---'
     O                                         +  2 '----'
     O                                         +  2 '---------'
     O                                         +  2 '---------'
     O                                         +  2 '-----------'
     O*
     O          E            DTL         1  1
     O                       STUID               10
     O                       STUNAM            +  2
     O                       STUMAJ              55
     O                       STUGRD            +  2
     O                       STUGPA        Z   +  2
     O                       STUENDT           +  2
     O                       STUBDT            +  2
     O                       STUEML            +  2
     O*
     O          E            END              01
     O                                           69 'END OF STUDENT REPORT'