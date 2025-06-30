library ExecuteDLL;


uses
  System.SysUtils,
  System.Classes,
  Windows,
  Generics.Collections,
  TaskAPI in '..\Common\TaskAPI.pas',
  uAnonumousThreadPool in '..\Common\uAnonumousThreadPool.pas';

type
  TShellExecuter = class(TInterfacedObject, ITaskProvider, IShellExecuter)
  private
    FProcessList: TList<DWORD>;
  public
    constructor Create;
    destructor Destroy; override;
    function GetTasks: TArray<TTaskInfo>;
    function ExecuteTask(const TaskName: string; const Params: string): TThread;
    function ExecuteShellCommand(const Command: string): DWORD;
    function WaitForCommandCompletion(AProcessID: DWORD; Timeout: integer): Boolean;
  end;

{$R *.res}

{ TShellExecuter }

constructor TShellExecuter.Create;
begin
  FProcessList := TList<DWORD>.Create;
end;

destructor TShellExecuter.Destroy;
begin
  FProcessList.Free;
  inherited;
end;

function TShellExecuter.ExecuteShellCommand(const Command: string): DWORD;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  CommandLine: string;
begin
  Result := 0;
  FillChar(StartupInfo, SizeOf(StartupInfo), 0);
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_SHOW; // показываем окно

  CommandLine := Command;

  if CreateProcess(nil, PChar(CommandLine), nil, nil, False, 0, nil, nil, StartupInfo, ProcessInfo) then
  begin
    Result := ProcessInfo.dwProcessId;
    FProcessList.Add(Result);
    CloseHandle(ProcessInfo.hThread); // Закрываем дескриптор потока
    CloseHandle(ProcessInfo.hProcess); // Закрываем дескриптор процесса
  end;
end;

function TShellExecuter.ExecuteTask(const TaskName, Params: string): TThread;
begin
  Result := nil;
  if Params.Length > 0 then
    ExecuteShellCommand(Params);
end;

function TShellExecuter.GetTasks: TArray<TTaskInfo>;
begin
  SetLength(Result, 1);
  Result[0].Name := 'Выполнение команд';
  Result[0].Parameters := 'Команда';
end;

function TShellExecuter.WaitForCommandCompletion(AProcessID: DWORD; Timeout: integer): Boolean;
var
  hProcess: THandle;
begin
  Result := false;
  if AProcessID <> 0 then
  begin
    hProcess := OpenProcess(PROCESS_QUERY_INFORMATION, False, AProcessID);
    if hProcess <> 0 then
    begin
      Result := WaitForSingleObject(hProcess, Timeout*1000) <> WAIT_OBJECT_0;
      CloseHandle(hProcess);
    end
  end;
end;

function CreateTaskProvider: IShellExecuter;
begin
  Result := TShellExecuter.Create;
end;


exports
  CreateTaskProvider;

begin
end.
