unit TaskAPI;

{$i RunTasks.inc}
interface

uses
  SysUtils, Classes,
  Generics.Collections,
  Threading,
  Winapi.Windows;

type
  TTaskInfo = record
    Name: string;
    Parameters: string;
  end;

type
  TResultThread =
  {$ifdef use_otl}
    integer
  {$else}
    TThread
  {$endif}
  ;
  ITaskProvider = interface
    ['{107439F7-F255-4EF3-9913-2E3950A872FE}']
    function GetTasks: TArray<TTaskInfo>;
    function ExecuteTask(const TaskName: string; const Params: string): TResultThread;
  end;

  IFileFinder = interface(ITaskProvider)
    ['{DC01A90C-C75D-4541-9697-2D0969373BE7}']
    function Start(const Command, Param: string; operation: integer): TResultThread;
    procedure Stop(AThread: TResultThread);
    function GetFilePaths(AThread: TResultThread): TStringList;
    function GetPositions(AThread: TResultThread): TList<integer>;
    function CheckRunning(AThread: TResultThread): boolean;
  end;

  IShellExecuter = interface(ITaskProvider)
    ['{C72B8096-E830-4FB0-8074-779B4A6650C2}']
    function ExecuteShellCommand(const Command: string): DWORD;
    function WaitForCommandCompletion(AProcessID: DWORD; Timeout: integer): Boolean;
  end;

  function LoadTaskDLL(const FileName: string): ITaskProvider;

implementation

function LoadTaskDLL(const FileName: string): ITaskProvider;
var
  CreateProc: function: ITaskProvider; stdcall;
  LibHandle: HMODULE;
begin
  Result := nil;
  LibHandle := LoadLibrary(PChar(FileName));
  if LibHandle <> 0 then
  begin
    @CreateProc := GetProcAddress(LibHandle, 'CreateTaskProvider');
    if Assigned(CreateProc) then
      Result := CreateProc;
  end;
end;

end.
