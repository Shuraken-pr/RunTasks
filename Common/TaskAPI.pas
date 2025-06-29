unit TaskAPI;

interface

uses
  SysUtils, Classes,
  Generics.Collections;

type
  TTaskInfo = record
    Name: string;
    Parameters: string;
  end;

  ITaskProvider = interface
    ['{107439F7-F255-4EF3-9913-2E3950A872FE}']
    function GetTasks: TArray<TTaskInfo>;
    function ExecuteTask(const TaskName: string; const Params: string): Integer;
  end;

  IFileFinder = interface(ITaskProvider)
    ['{DC01A90C-C75D-4541-9697-2D0969373BE7}']
    procedure Start(const Command, Param: string; operation: integer);
    procedure Stop;
    function GetFilePaths: TStringList;
    function GetPositions: TList<integer>;
    function CheckRunning: boolean;
  end;

  IShellExecuter = interface(ITaskProvider)
    ['{C72B8096-E830-4FB0-8074-779B4A6650C2}']
    function ExecuteShellCommand(const Command: string): Boolean;
    function WaitForCommandCompletion(Timeout: integer): Boolean;
  end;

  function LoadTaskDLL(const FileName: string): ITaskProvider;

implementation

uses
  Windows;

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
