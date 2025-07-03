unit uOTLThreadManager;

interface

uses
System.Classes, System.SysUtils, System.Generics.Collections,
  OtlTask, OtlTaskControl, OtlParallel;

type
  TThreadManager = class
  private
    FThreads: TDictionary<integer, IOmniTaskControl>;
    FNextID: integer;
    FThreadLock: TObject;
  public
    constructor Create;
    destructor Destroy; override;

    function Start(AProc: TProc): integer;
    procedure Stop(AThreadID: integer);
    procedure TerminateAllThreads;
    function IsThreadRunning(AThreadID: integer): boolean;
  end;

implementation

constructor TThreadManager.Create;
begin
  inherited;
  FThreads := TDictionary<integer, IOmniTaskControl>.Create;
  FThreadLock := TObject.Create;
  FNextID := 1;
end;

destructor TThreadManager.Destroy;
begin
  TerminateAllThreads;
  FreeAndNil(FThreads);
  FreeAndNil(FThreadLock);
  inherited;
end;

function TThreadManager.Start(AProc: TProc): integer;
var
  task: IOmniTaskControl;
  threadID: integer;
begin
  TMonitor.Enter(FThreadLock);
  try
    threadID := FNextID;
    Inc(FNextID);

    task := CreateTask(
      procedure (const task: IOmniTask)
      begin
        if Assigned(AProc) then
          AProc();
      end)
      .OnTerminated(
        procedure (const task: IOmniTaskControl)
        begin
          TMonitor.Enter(FThreadLock);
          try
            FThreads.Remove(task.UniqueID);
          finally
            TMonitor.Exit(FThreadLock);
          end;
        end)
      .Unobserved
      .Run;

    TOmniTaskControl(task).SharedInfo.UniqueID := threadID;
    FThreads.Add(threadID, task);

    Result := threadID;
  finally
    TMonitor.Exit(FThreadLock);
  end;
end;

procedure TThreadManager.Stop(AThreadID: integer);
var
  task: IOmniTaskControl;
begin
  TMonitor.Enter(FThreadLock);
  try
    if FThreads.TryGetValue(AThreadID, task) then
    begin
      task.Terminate;
      FThreads.Remove(AThreadID);
    end;
  finally
    TMonitor.Exit(FThreadLock);
  end;
end;

procedure TThreadManager.TerminateAllThreads;
var
  pair: TPair<integer, IOmniTaskControl>;
begin
  TMonitor.Enter(FThreadLock);
  try
    for pair in FThreads do
      pair.Value.Terminate;
    FThreads.Clear;
  finally
    TMonitor.Exit(FThreadLock);
  end;
end;

function TThreadManager.IsThreadRunning(AThreadID: integer): boolean;
begin
  TMonitor.Enter(FThreadLock);
  try
    Result := FThreads.ContainsKey(AThreadID);
  finally
    TMonitor.Exit(FThreadLock);
  end;
end;

end.
