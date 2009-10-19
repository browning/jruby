@echo off
rem Environment Variable Prequisites:
rem
rem   JRUBY_CP    JRuby's bootclasspath.
rem

set _MEM=-Xmx500m
if not defined JAVA_MEM goto memOptDone
set _MEM=%JAVA_MEM%
:memOptDone

set _STK=-Xss1024k
if not defined JAVA_STACK goto stackOptDone
set _STK=%JAVA_STACK%
:stackOptDone

set _VM_OPTS=
set _RUBY_OPTS=
set _DFLT_VM_OPTS=%JAVA_OPTS%
set _JAVA_VM=-client
set _JAVA_CLASS=org.jruby.Main
set _JRUBY_BOOTCP_OPTS=-Xbootclasspath/a:"%JRUBY_CP%"

set SAFE_JAVA_HOME=%JAVA_HOME:(=^^(%
set SAFE_JAVA_HOME=%SAFE_JAVA_HOME:)=^^)%

if not exist "%SAFE_JAVA_HOME%\bin\java.exe" goto noJavaHome
goto okJavaHome

:noJavaHome
echo The JAVA_HOME environment variable is not defined correctly.
echo Please set JAVA_HOME to the path to your JDK installation.
set JRUBY_BAT_ERROR=1
goto :EOF
:okJavaHome

rem
rem Can you believe I'm rewriting batch arg processing in batch files because batch
rem file arg processing sucks so bad? Can you believe this is even possible?
rem http://support.microsoft.com/kb/71247

rem Escape any quotes. Use _S for ', _D for ", _P for |, _G for >, _L for <,
rem _C to escape ^, and _U to escape _ itself. We have to escape _ itself,
rem otherwise file names with _S and _D will be converted to to wrong ones,
rem when we un-escape. See JRUBY-2821.
set _ARGS=%*
if not defined _ARGS goto vmoptsDone
set _ARGS=!_ARGS:_=_U!
set _ARGS=!_ARGS:^>=_G!
set _ARGS=!_ARGS:^<=_L!
set _ARGS=!_ARGS:^|=_P!
set _ARGS=!_ARGS:^?=_Q!
set _ARGS=!_ARGS:%%=_R!
set _ARGS=!_ARGS:^^=_C!
set _ARGS=!_ARGS:'=_S!
set _ARGS=!_ARGS:"=_D!

rem prequote all args for 'for' statement
set _ARGS="%_ARGS%"

:vmoptsLoop
rem split args by spaces into first and rest
for /f "tokens=1,*" %%i in (%_ARGS%) do call :getarg "%%i" "%%j"
goto procarg

:getarg
rem remove quotes around first arg
for %%i in (%1) do set _CMP=%%~i
rem set the rest args (note, they're all quoted and ready to go)
set _ARGS=%2
rem return to line 18
goto :EOF

:procarg
if ["%_CMP%"] == [""] goto vmoptsDone

REM NOTE: If you'd like to use a parameter with underscore in its name,
REM NOTE: use the quoted value: --do_stuff -> --do_Ustuff

if ["%_CMP%"] == ["--server"] (
  set _JAVA_VM=-server
  goto :vmoptsNext
)

if ["%_CMP%"] == ["--client"] (
  set _JAVA_VM=-client
  goto :vmoptsNext
)

if ["%_CMP%"] == ["--jdb"] (
  set _STARTJAVA=%SAFE_JAVA_HOME%\bin\jdb
  goto :vmoptsNext
)

if ["%_CMP%"] == ["--sample"] (
  set _CMP=-J-Xprof
  goto :jvmarg
)

if ["%_CMP%"] == ["--manage"] (
  set _CMP=-J-Dcom.sun.management.jmxremote
  goto :jvmarg
)

if ["%_CMP%"] == ["--1.9"] (
  set _CMP=-J-Djruby.compat.version=RUBY1_9
  goto :jvmarg
)

if ["%_CMP%"] == ["--1.8"] (
  set _CMP=-J-Djruby.compat.version=RUBY1_8
  goto :jvmarg
)

if ["%_CMP%"] == ["--ng-server"] (
  set _JAVA_CLASS=com.martiansoftware.nailgun.NGServer
  set _JAVA_VM=-server
  rem Nailgun server fails if -Xbootclasspath is used, so we remove it here.
  rem In com.martiansoftware.nailgun.AliasManager's constructor, 
  rem getResourceAsStream("com/martiansoftware/nailgun/builtins/builtins.properties")
  rem returns null, which is not handled, crashing the server. Removing
  rem -Xbootclasspath for some reason fixes the getResourceAsStream() call.
  set _JRUBY_BOOTCP_OPTS=
  set CP=%JRUBY_CP%;%CP%
  goto :vmoptsNext
)

if ["%_CMP%"] == ["--ng"] (
  set _NAILGUN_CLIENT=true
  goto :vmoptsNext
)

rem now unescape _G, _L, _P, _E, _D, _S, _C and _U
set _CMP=!_CMP:_D="!
set _CMP=!_CMP:_S='!
set _CMP=!_CMP:_E=^=!
set _CMP=!_CMP:_Q=^?!
set _CMP=!_CMP:_P=^|!
set _CMP=!_CMP:_R=%%!
set _CMP=!_CMP:_C=^^!
set _CMP=!_CMP:_L=^<!
set _CMP=!_CMP:_G=^>!
set _CMP=!_CMP:_U=_!

set _CMP1=!_CMP:~0,1!
set _CMP2=!_CMP:~0,2!

rem detect first character is a quote; skip directly to rubyarg
rem this avoids a batch syntax error
if "%_CMP1:"=\\%" == "\\" goto rubyarg

rem removing quote avoids a batch syntax error
if "%_CMP2:"=\\%" == "-J" goto jvmarg

:rubyarg
set _RUBY_OPTS=%_RUBY_OPTS% %_CMP%
goto vmoptsNext

:jvmarg
set _VAL=%_CMP:~2%

if "%_VAL:~0,4%" == "-Xmx" (
  set _MEM=%_VAL%
  goto vmoptsNext
)

if "%_VAL:~0,4%" == "-Xss" (
  set _STK=%_VAL%
  goto vmoptsNext
)

rem Make sure the older way to specify server VM
rem is still supported.
if ["%_VAL%"] == ["-server"] (
  set _JAVA_VM=-server
  goto vmoptsNext
)

set _VM_OPTS=%_VM_OPTS% %_VAL%

:vmoptsNext
set _CMP=
goto vmoptsLoop

:vmoptsDone

:rubyoptsDone
set _VM_OPTS=%_VM_OPTS% %_JAVA_VM% %_MEM% %_STK% %_DFLT_VM_OPTS%
set _DFLT_VM_OPTS=
set _MEM=
set _STK=
set _ARGS=
set _VAL=
set _CMP=
set _CMP1=
set _JAVA_VM=