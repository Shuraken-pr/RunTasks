library ExecuteDLL;


uses
  System.SysUtils,
  System.Classes,
  Windows,
  TaskAPI in '..\Common\TaskAPI.pas';

type
  TShellExecuter = class(TInterfacedObject, ITaskProvider, IShellExecuter)
  private
    FProcessID: DWORD;
  public
    constructor Create;
    function GetTasks: TArray<TTaskInfo>;
    function ExecuteTask(const TaskName: string; const Params: string): Integer;
    function ExecuteShellCommand(const Command: string): Boolean;
    function WaitForCommandCompletion(Timeout: integer): Boolean;
  end;

{$R *.res}

{ TShellExecuter }

constructor TShellExecuter.Create;
begin
  FProcessID := 0;
end;

function TShellExecuter.ExecuteShellCommand(const Command: string): Boolean;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  CommandLine: string;
begin
  Result := False;
  FillChar(StartupInfo, SizeOf(StartupInfo), 0);
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_SHOW; // показываем окно

  CommandLine := Command;

  if CreateProcess(nil, PChar(CommandLine), nil, nil, False, 0, nil, nil, StartupInfo, ProcessInfo) then
  begin
    FProcessID := ProcessInfo.dwProcessId;
    CloseHandle(ProcessInfo.hThread); // Закрываем дескриптор потока
    CloseHandle(ProcessInfo.hProcess); // Закрываем дескриптор процесса
    Result := True;
  end;
end;

function TShellExecuter.ExecuteTask(const TaskName, Params: string): Integer;
begin
  Result := -1;
  if Params.Length > 0 then
  begin
    Result := 0;
    ExecuteShellCommand(Params);
  end;
end;

function TShellExecuter.GetTasks: TArray<TTaskInfo>;
begin
  SetLength(Result, 1);
  Result[0].Name := 'Выполнение команд';
  Result[0].Parameters := 'Команда';
end;

function TShellExecuter.WaitForCommandCompletion(Timeout: integer): Boolean;
var
  hProcess: THandle;
begin
  Result := false;
  if FProcessID <> 0 then
  begin
    hProcess := OpenProcess(PROCESS_QUERY_INFORMATION, False, FProcessID);
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
