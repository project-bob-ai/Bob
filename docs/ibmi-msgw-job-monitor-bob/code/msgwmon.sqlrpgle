**free
// ===========================================================================
// Program   : MSGWMON
// Source    : BOB4IPGMR/QRPGLESRC,MSGWMON  (SQLRPGLE)
// Purpose   : Real-time job monitor - displays all jobs in MSGW (Message
//             Wait) status.  Operators can take action on each listed job.
//
// Options available:
//   2 = Work With Job    (WRKJOB)
//   3 = Hold Job         (HLDJOB)
//   4 = End Job Cntrl    (ENDJOB OPTION(*CNTRLD))
//   5 = Display Messages (WRKJOB OPTION(*MSG))
//   6 = Release Job      (RLSJOB)
//   7 = Display Job Log  (DSPJOBLOG)
//   8 = End Job Immed    (ENDJOB OPTION(*IMMED))
//
// Function Keys:
//   F3  = Exit  |  F5 = Refresh  |  F12 = Cancel
//
// Notes:
//   - ACTIVE_JOB_INFO.JOB_NAME is the full qualified name (number/user/name).
//     SFQJOB is assigned directly from it; SUBSTR extracts the short name.
//   - QCMDEXC Cmd parameter is char OPTIONS(*VARSIZE) per IBM documentation.
//     Passing varchar to a char CONST parameter works via auto-conversion.
//     Using varchar(32702) caused the 2-byte length prefix to appear as two
//     leading spaces in the command string, producing 'invalid character' errors.
// ===========================================================================

// ---------------------------------------------------------------------------
// Control options
// ---------------------------------------------------------------------------
ctl-opt dftactgrp(*no) actgrp(*new);
ctl-opt option(*srcstmt: *nodebugio);
ctl-opt datfmt(*iso) timfmt(*iso);

// ---------------------------------------------------------------------------
// Standalone variables required before file declaration (used in SFILE)
// ---------------------------------------------------------------------------
dcl-s WkRRN     zoned(4:0);    // Subfile RRN (zoned required by SFILE keyword)

// ---------------------------------------------------------------------------
// File declarations
// ---------------------------------------------------------------------------
dcl-f MSGWDSPF workstn sfile(MSGSFL: WkRRN) indds(Ind);

// ---------------------------------------------------------------------------
// Indicator data structure
// ---------------------------------------------------------------------------
dcl-ds Ind;
  F3Exit        ind pos(3);
  F5Refresh     ind pos(5);
  F12Cancel     ind pos(12);
  SflDsp        ind pos(31);
  SflDspCtl     ind pos(32);
  SflClr        ind pos(33);
  SflEnd        ind pos(34);
  CntGrn        ind pos(35);
  MsgDsp        ind pos(90);
  MsgClr        ind pos(91);
end-ds;

// ---------------------------------------------------------------------------
// Standalone variables
// ---------------------------------------------------------------------------
dcl-s WkCmd     varchar(512);
dcl-s WkCmdLen  packed(15:5);
dcl-s WkQualJob varchar(28);
dcl-s WkJobCnt  packed(4:0);
dcl-s WkMsgText varchar(100);
dcl-s WkEof     ind;

// ---------------------------------------------------------------------------
// Prototypes
// ---------------------------------------------------------------------------
// QCMDEXC: Cmd MUST be char OPTIONS(*VARSIZE), NOT varchar.
// Passing varchar to varchar(*VARSIZE) sends the internal 2-byte length
// prefix as part of the data  causing 'invalid character' command errors.
// With char OPTIONS(*VARSIZE) + CONST, RPG auto-converts the varchar WkCmd
// and passes exactly %len(WkCmd) bytes of clean character data.
dcl-pr QCMDEXC extpgm('QCMDEXC');
  Cmd     char(32702) options(*varsize) const;   // char  NOT varchar
  CmdLen  packed(15:5)                 const;
end-pr;

dcl-pr SendPgmMsg extpgm('QMHSNDPM');
  MsgId    char(7)    const;
  MsgFile  char(20)   const;
  MsgData  char(256)  const;
  MsgDLen  int(10)    const;
  MsgType  char(10)   const;
  CallStkE char(10)   const;
  CallStkC int(10)    const;
  MsgKey   char(4);
  ErrCode  char(256);
end-pr;

// ---------------------------------------------------------------------------
// Host variables for the SQL cursor
// ---------------------------------------------------------------------------
dcl-ds JobRow qualified;
  // JOB_NAME from ACTIVE_JOB_INFO is already 'number/user/name' (28 chars).
  JobName      varchar(28);
  // Extracted short name (after second slash)  used for display only.
  JobShortName varchar(10);
  JobUser      varchar(10);
  JobNumber    varchar(6);
  JobType      varchar(3);
  Subsystem    varchar(10);
  FuncType     varchar(2);
  Function     varchar(10);
end-ds;

// ---------------------------------------------------------------------------
// Miscellaneous working variables
// ---------------------------------------------------------------------------
dcl-s MsgKey   char(4);
dcl-s ErrCode  char(256) inz;
dcl-s NullBuf  char(7)   inz;

// ============================================================================
// Mainline
// ============================================================================

write FOOTER;

dou F3Exit;

  exsr LoadSubfile;

  exfmt MSGCTL;

  if F3Exit;
    leave;
  endif;

  if F5Refresh or F12Cancel;
    iter;
  endif;

  exsr ProcessOptions;

enddo;

MsgClr = *on;
write MSGQCTL;
MsgClr = *off;

*inlr = *on;
return;

// ============================================================================
// Subroutine: LoadSubfile
// ============================================================================
begsr LoadSubfile;

  SflDsp    = *off;
  SflDspCtl = *off;
  SflClr    = *on;
  SflEnd    = *off;
  CntGrn    = *off;
  CTJOBCNT  = 0;
  write MSGCTL;
  SflClr    = *off;

  MsgClr = *on;
  write MSGQCTL;
  MsgClr = *off;
  MsgDsp = *off;

  WkJobCnt = 0;
  WkRRN    = 0;

  exec sql
    DECLARE C_MSGWJOBS CURSOR FOR
      SELECT
        -- JOB_NAME is the full qualified name: 'number/user/name'
        JOB_NAME,
        -- Extract short job name (everything after the second '/')
        SUBSTR(JOB_NAME,
               LOCATE('/', JOB_NAME, LOCATE('/', JOB_NAME) + 1) + 1)
          AS JOB_NAME_SHORT,
        JOB_USER,
        JOB_NUMBER,
        COALESCE(JOB_TYPE,      '   '),
        COALESCE(SUBSYSTEM,     '          '),
        COALESCE(FUNCTION_TYPE, '  '),
        COALESCE(FUNCTION,      '          ')
      FROM TABLE(QSYS2.ACTIVE_JOB_INFO())
      WHERE JOB_STATUS = 'MSGW'
      ORDER BY JOB_TYPE, SUBSYSTEM, JOB_USER, JOB_NAME;

  exec sql OPEN C_MSGWJOBS;

  if SQLCODE < 0;
    WkMsgText = 'SQL error (SQLCODE=' + %char(SQLCODE) + ').';
    exsr SendMsgText;
  else;

    exec sql
      FETCH NEXT FROM C_MSGWJOBS
      INTO :JobRow.JobName,  :JobRow.JobShortName,
           :JobRow.JobUser,  :JobRow.JobNumber,
           :JobRow.JobType,  :JobRow.Subsystem,
           :JobRow.FuncType, :JobRow.Function;

    dow SQLCODE = 0;
      WkJobCnt += 1;
      WkRRN    += 1;

      SFOPT      = '   ';
      SFJOBNUM   = %char(JobRow.JobNumber);
      SFJOBUSR   = %char(JobRow.JobUser);
      // JobShortName is the short job name only (e.g. ORDPROC)
      SFJOBNAM   = %char(JobRow.JobShortName);
      SFJOBTYP   = %char(JobRow.JobType);
      SFSUBSYS   = %char(JobRow.Subsystem);
      SFTYPE     = %char(JobRow.FuncType);
      SFFUNCTION = %char(JobRow.Function);
      // JOB_NAME is already 'number/user/name'  store directly in hidden field
      SFQJOB     = %char(JobRow.JobName);

      write MSGSFL;

      exec sql
        FETCH NEXT FROM C_MSGWJOBS
        INTO :JobRow.JobName,  :JobRow.JobShortName,
             :JobRow.JobUser,  :JobRow.JobNumber,
             :JobRow.JobType,  :JobRow.Subsystem,
             :JobRow.FuncType, :JobRow.Function;
    enddo;

    exec sql CLOSE C_MSGWJOBS;

    if WkJobCnt = 0;
      WkMsgText = 'No jobs currently in MSGW status. Press F5 to refresh.';
      exsr SendMsgText;
    endif;

  endif;

  CTJOBCNT  = WkJobCnt;
  CntGrn    = (WkJobCnt > 0);
  SflDsp    = (WkJobCnt > 0);
  SflDspCtl = *on;
  SflClr    = (WkJobCnt = 0);
  SflEnd    = *on;

endsr;

// ============================================================================
// Subroutine: ProcessOptions
// READC reads only subfile rows the operator modified (typed an option).
// WkQualJob is varchar  no trailing-space issues when building CL commands.
// ============================================================================
begsr ProcessOptions;

  WkEof = *off;
  readc MSGSFL;
  WkEof = %eof(MSGWDSPF);

  dow not WkEof;

    if %trim(SFOPT) = '';
      readc MSGSFL;
      WkEof = %eof(MSGWDSPF);
      iter;
    endif;

    // SFQJOB is char(28); %trimr strips trailing spaces before assigning to varchar
    WkQualJob = %trimr(SFQJOB);

    select;

      // 2 = Work With Job
      when %trim(SFOPT) = '2';
        WkCmd    = 'WRKJOB JOB(' + WkQualJob + ')';
        WkCmdLen = %len(WkCmd);
        QCMDEXC(WkCmd: WkCmdLen);

      // 3 = Hold Job
      when %trim(SFOPT) = '3';
        WkCmd    = 'HLDJOB JOB(' + WkQualJob + ') DUPJOBOPT(*MSG)';
        WkCmdLen = %len(WkCmd);
        monitor;
          QCMDEXC(WkCmd: WkCmdLen);
          WkMsgText = 'Hold submitted: ' + WkQualJob;
          exsr SendMsgText;
        on-error;
          WkMsgText = 'Hold failed: ' + WkQualJob + '. Check job log.';
          exsr SendMsgText;
        endmon;

      // 4 = End Job (Controlled)
      when %trim(SFOPT) = '4';
        WkCmd    = 'ENDJOB JOB(' + WkQualJob +
                   ') OPTION(*CNTRLD) DELAY(30) DUPJOBOPT(*MSG)';
        WkCmdLen = %len(WkCmd);
        monitor;
          QCMDEXC(WkCmd: WkCmdLen);
          WkMsgText = 'End (Ctrl) submitted: ' + WkQualJob;
          exsr SendMsgText;
        on-error;
          WkMsgText = 'End (Ctrl) failed: ' + WkQualJob + '. Check job log.';
          exsr SendMsgText;
        endmon;

      // 5 = Display Messages (WRKJOB OPTION(*MSG) opens the job message queue)
      when %trim(SFOPT) = '5';
        WkCmd    = 'WRKJOB JOB(' + WkQualJob + ') OPTION(*MSG)';
        WkCmdLen = %len(WkCmd);
        QCMDEXC(WkCmd: WkCmdLen);

      // 6 = Release Job
      when %trim(SFOPT) = '6';
        WkCmd    = 'RLSJOB JOB(' + WkQualJob + ') DUPJOBOPT(*MSG)';
        WkCmdLen = %len(WkCmd);
        monitor;
          QCMDEXC(WkCmd: WkCmdLen);
          WkMsgText = 'Release submitted: ' + WkQualJob;
          exsr SendMsgText;
        on-error;
          WkMsgText = 'Release failed: ' + WkQualJob + '. Check job log.';
          exsr SendMsgText;
        endmon;

      // 7 = Display Job Log
      when %trim(SFOPT) = '7';
        WkCmd    = 'DSPJOBLOG JOB(' + WkQualJob + ') OUTPUT(*)';
        WkCmdLen = %len(WkCmd);
        QCMDEXC(WkCmd: WkCmdLen);

      // 8 = End Job (Immediate)
      when %trim(SFOPT) = '8';
        WkCmd    = 'ENDJOB JOB(' + WkQualJob +
                   ') OPTION(*IMMED) DUPJOBOPT(*MSG)';
        WkCmdLen = %len(WkCmd);
        monitor;
          QCMDEXC(WkCmd: WkCmdLen);
          WkMsgText = 'End (Immed) submitted: ' + WkQualJob;
          exsr SendMsgText;
        on-error;
          WkMsgText = 'End (Immed) failed: ' + WkQualJob + '. Check job log.';
          exsr SendMsgText;
        endmon;

      other;
        WkMsgText = 'Option "' + %trimr(SFOPT) + '" not valid. Use 2-8.';
        exsr SendMsgText;

    endsl;

    SFOPT = '   ';
    update MSGSFL;

    readc MSGSFL;
    WkEof = %eof(MSGWDSPF);

  enddo;

endsr;

// ============================================================================
// Subroutine: SendMsgText
// ============================================================================
begsr SendMsgText;

  MsgClr = *on;
  write MSGQCTL;
  MsgClr = *off;

  SendPgmMsg(
    NullBuf :
    '                    ' :
    %char(WkMsgText) :
    %len(%trimr(WkMsgText)) :
    '*INFO     ' :
    '*EXT      ' :
    0 :
    MsgKey :
    ErrCode
  );

  MsgDsp = *on;
  write MSGQCTL;

endsr;

