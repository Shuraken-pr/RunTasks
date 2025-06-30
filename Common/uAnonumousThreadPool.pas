unit uAnonumousThreadPool;

interface

uses
  System.Classes, System.SysUtils, System.Types, Threading;

type
  TAnonumousThreadPool = class(TObject)
  strict private
    FThreadList: TThreadList;
    procedure TerminateRunningThreads;
    procedure AnonumousThreadTerminate(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override; final;
    function Start(const Proc: TProc): TThread;
    procedure Stop(AThread: TThread);
  end;

implementation

{ TAnonumousThreadPool }

function TAnonumousThreadPool.Start(const Proc: TProc): TThread;
begin
  Result := TThread.CreateAnonymousThread(Proc);
  Result.OnTerminate := AnonumousThreadTerminate;
  Result.FreeOnTerminate := True;
  FThreadList.LockList;
  try
    FThreadList.Add(Result);
  finally
    FThreadList.UnlockList;
  end;
  Result.Start;
end;

procedure TAnonumousThreadPool.Stop(AThread: TThread);
begin
  if AThread.ThreadID <> 0 then
  begin
    FThreadList.LockList;
    try
      FThreadList.Remove(AThread);
    finally
      FThreadList.UnlockList;
    end;
  end;
end;

procedure TAnonumousThreadPool.AnonumousThreadTerminate(Sender: TObject);
begin
  FThreadList.LockList;
  try
    FThreadList.Remove(Sender);
  finally
    FThreadList.UnlockList;
  end;
end;

procedure TAnonumousThreadPool.TerminateRunningThreads;
var
  L: TList;
  T: TThread;
begin
  if not Assigned(FThreadList) then
    Exit;

  L := FThreadList.LockList;
  try
    while L.Count > 0 do
    begin
      T := TThread(L[0]);
      L.Remove(T);
      T.OnTerminate := nil; // Убираем обработчик
      if not T.Finished then
        T.Terminate; // Запускаем завершение потока
    end;
  finally
    FThreadList.UnlockList;
  end;
  FThreadList.Free; // Освобождаем список потоков
end;

constructor TAnonumousThreadPool.Create;
begin
  FThreadList := TThreadList.Create;
  FThreadList.Duplicates := TDuplicates.dupError;
end;

destructor TAnonumousThreadPool.Destroy;
begin
  TerminateRunningThreads;
  inherited;
end;

end.
