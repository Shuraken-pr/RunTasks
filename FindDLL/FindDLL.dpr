library FindDLL;

uses
  System.SysUtils,
  System.Classes,
  TaskAPI in '..\Common\TaskAPI.pas',
  SyncObjs,
  Generics.Collections;

type
  TFindFilesTask = class(TInterfacedObject, ITaskProvider, IFileFinder)
  private
    FThread: TThread;
    FFilePaths: TStringList;
    FSearchMask: string;
    FRootPath: string;
    FFileName: string;
    FStringToFind: string;
    FIsSearching: Boolean;
    FLock: TCriticalSection;
    FPositions: TList<integer>;
    procedure FindFilesInDir(const Dir: string);
    function CountStringOccurrences(const FileName, StringToFind: string): integer;
  public
    constructor Create;
    destructor Destroy; override;
    function GetTasks: TArray<TTaskInfo>;
    function ExecuteTask(const TaskName: string; const Params: string): Integer;
    procedure Start(const Command, Param: string; operation: integer);
    procedure Stop;
    function GetFilePaths: TStringList;
    function GetPositions: TList<integer>;
    function CheckRunning: boolean;
  end;

{$R *.res}

{ TFindFilesTask }

constructor TFindFilesTask.Create;
begin
  FFilePaths := TStringList.Create;
  FIsSearching := False;
  FLock := TCriticalSection.Create;
  FPositions := TList<integer>.Create;
  FRootPath := '';
  FSearchMask := '';
  FFileName := '';
  FStringToFind := '';
end;

destructor TFindFilesTask.Destroy;
begin
  Stop;
  FFilePaths.Free;
  FLock.Free;
  FPositions.Free;
  inherited;
end;

function TFindFilesTask.ExecuteTask(const TaskName, Params: string): Integer;
var
  path, FileName, stringToFind, mask: string;
  splitter: integer;
begin
  Result := -1;
  if TaskName = 'Поиск файлов' then
  begin
    splitter := params.IndexOf(',');
    if splitter > 0 then
    begin
      path := params.Substring(0, splitter);
      mask := Params.Substring(splitter + 1);
      if DirectoryExists(path) and (pos('*.', mask) > 0) and (length(mask) > 2) then
      begin
        Result := 0;
        Start(path, mask, 0);
      end;
    end;
  end
    else if TaskName = 'Поиск в файле' then
  begin
    splitter := params.IndexOf(',');
    if splitter > 0 then
    begin
      FileName := params.Substring(0, splitter);
      stringToFind := Params.Substring(splitter + 1);
      if FileExists(FileName) and (length(stringToFind) > 0) then
      begin
        Result := 0;
        Start(FileName, stringToFind, 1);
      end;
    end;
  end;
end;

procedure TFindFilesTask.FindFilesInDir(const Dir: string);
var
  SearchRec: TSearchRec;
begin
  if FindFirst(IncludeTrailingPathDelimiter(Dir) + FSearchMask, faAnyFile, SearchRec) = 0 then
  begin
    try
      repeat
        if not FIsSearching then Exit; // Проверяем флаг остановки
        FFilePaths.Add(IncludeTrailingPathDelimiter(Dir) + SearchRec.Name);
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;

  if not FIsSearching then
    Exit; // Проверяем флаг остановки

  // Рекурсивный поиск в подкаталогах
  if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faDirectory, SearchRec) = 0 then
  begin
    try
      repeat
        if (SearchRec.Attr and faDirectory <> 0) and (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
        begin
          FindFilesInDir(IncludeTrailingPathDelimiter(Dir) + SearchRec.Name);
        end;
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;
end;

function TFindFilesTask.GetFilePaths: TStringList;
begin
  Result := FFilePaths;
end;

function TFindFilesTask.GetPositions: TList<integer>;
begin
  Result := FPositions;
end;

function TFindFilesTask.GetTasks: TArray<TTaskInfo>;
begin
  SetLength(Result, 2);
  Result[0].Name := 'Поиск файлов';
  Result[0].Parameters := 'Каталог для поиска, расширение файлов';
  Result[1].Name := 'Поиск в файле';
  Result[1].Parameters := 'Файл, строка для поиска';
end;

procedure TFindFilesTask.Start(const Command, Param: string; operation: integer);
begin
  FLock.Acquire;
  try
    if not FIsSearching then
    begin
      FIsSearching := True;
      if operation = 0 then
      begin
        FSearchMask := Param;
        FRootPath := Command;
      end
        else
      begin
        FFileName := Command;
        FStringToFind := Param;
      end;
      FThread := TThread.CreateAnonymousThread(
        procedure
        begin
          if operation = 0 then
            FindFilesInDir(FRootPath)
          else
            CountStringOccurrences(FFileName, FStringToFind);
          FLock.Acquire;
          try
            FIsSearching := False;
          finally
            FLock.Release;
          end;
        end
      );
      FThread.FreeOnTerminate := true;
      FThread.Start;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TFindFilesTask.Stop;
begin
  FLock.Acquire;
  try
    if Assigned(FThread) and FIsSearching then // Проверяем, что поток существует и активен
    begin
      FIsSearching := False; // Устанавливаем флаг остановки
      FThread.Terminate;    // Просим поток завершиться
      FLock.Release;        // Освобождаем лок перед ожиданием, чтобы поток мог его захватить при завершении
      FThread.WaitFor;      // Ждем фактического завершения потока
      FLock.Acquire;        // Снова захватываем лок
      FThread := nil;       // Обнуляем ссылку после завершения и освобождения потока
    end
    else if Assigned(FThread) then // Если поток существует, но не активен (уже завершился сам)
      FThread := nil; // Просто обнуляем ссылку
    FIsSearching := False; // Убеждаемся, что флаг сброшен
  finally
    FLock.Release;
  end;
end;

function TFindFilesTask.CheckRunning: boolean;
begin
  Result := FIsSearching;
end;

function TFindFilesTask.CountStringOccurrences(const FileName, StringToFind: string): integer;
var
  Stream: TFileStream;
  Buffer: array of Byte;
  BufferSize: Integer;
  BytesRead, searchStringLength: integer;
  CurrentPosition: Integer;
  SearchString: AnsiString;
  i: integer;
begin
  Result := 0;
  if Assigned(FPositions) then
    FPositions.Clear;
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    BufferSize := 4096; // Оптимальный размер буфера
    SetLength(Buffer, BufferSize);
    SearchString := AnsiString(StringToFind); // Преобразуем строку в AnsiString
    searchStringLength := Length(SearchString);
    CurrentPosition := 0;

    while True do
    begin
      if not FIsSearching then
        Exit; // Проверяем флаг остановки
      BytesRead := Stream.Read(Buffer[0], BufferSize);
      if BytesRead = 0 then
        Break;

      // Ищем в буфере
      for i := 0 to BytesRead - searchStringLength do
      begin
        if CompareMem(@Buffer[i], PAnsiChar(SearchString), Length(SearchString)) then
        begin
          if Assigned(FPositions) then
            FPositions.Add(CurrentPosition + i);
          Inc(Result); // Увеличиваем счетчик
        end;
      end;

      CurrentPosition := CurrentPosition + BytesRead; // Обновляем текущую позицию
    end;
  finally
    Stream.Free;
  end;
end;

function CreateTaskProvider: IFileFinder;
begin
  Result := TFindFilesTask.Create;
end;


exports
  CreateTaskProvider;

begin
end.
