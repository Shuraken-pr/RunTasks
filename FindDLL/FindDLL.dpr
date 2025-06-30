library FindDLL;

uses
  System.SysUtils,
  System.Classes,
  TaskAPI in '..\Common\TaskAPI.pas',
  SyncObjs,
  Generics.Collections,
  System.Masks,
  uAnonumousThreadPool in '..\Common\uAnonumousThreadPool.pas';

type
  TResultTask = class(TObject)
  private
    FPositions: TList<integer>;
    FFilePaths: TStringList;
    FIsSearching: boolean;
    FThread: TThread;
    FSearchMasks: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    property SearchMasks: TStringList read FSearchMasks write FSearchMasks;
    property IsSearching: boolean read FIsSearching write FIsSearching;
    property FilePaths: TStringList read FFilePaths write FFilePaths;
    property Positions: TList<integer> read FPositions write FPositions;
    property Thread: TThread read FThread write FThread;
  end;

  TResultTaskList = class(TObjectList<TResultTask>)
     function FindResultTaskByThread(AThread: TThread): TResultTask;
  end;

  TFindFilesTask = class(TInterfacedObject, ITaskProvider, IFileFinder)
  private
    FSearchMask: string;
    FRootPath: string;
    FFileName: string;
    FStringToFind: string;
    FThreadPool: TAnonumousThreadPool;
    FResultTaskList: TResultTaskList;
    procedure FindFilesInDir(const Dir: string; SearchMasks: TStringList; const IsSearching: boolean; FilePaths: TStringList);
    function CountStringOccurrences(const FileName, StringToFind: string; const IsSearching: boolean; Positions: TList<integer>): integer;
  public
    constructor Create;
    destructor Destroy; override;
    function GetTasks: TArray<TTaskInfo>;
    function ExecuteTask(const TaskName: string; const Params: string): TThread;
    function Start(const Command, Param: string; operation: integer): TThread;
    procedure Stop(AThread: TThread);
    function GetFilePaths(AThread: TThread): TStringList;
    function GetPositions(AThread: TThread): TList<integer>;
    function CheckRunning(AThread: TThread): boolean;
  end;

{$R *.res}

{ TFindFilesTask }

constructor TFindFilesTask.Create;
begin
  FRootPath := '';
  FSearchMask := '';
  FFileName := '';
  FStringToFind := '';
  FThreadPool := TAnonumousThreadPool.Create;
  FResultTaskList := TResultTaskList.Create(true);
end;

destructor TFindFilesTask.Destroy;
begin
  FThreadPool.Free;
  FResultTaskList.Free;
  inherited;
end;

function TFindFilesTask.ExecuteTask(const TaskName, Params: string): TThread;
var
  path, FileName, stringToFind, mask: string;
  splitter: integer;
begin
  Result := nil;
  if TaskName = 'Поиск файлов' then
  begin
    splitter := params.IndexOf(',');
    if splitter > 0 then
    begin
      path := params.Substring(0, splitter);
      mask := Params.Substring(splitter + 1);
      if DirectoryExists(path) and (pos('*.', mask) > 0) and (length(mask) > 2) then
      begin
        Result := Start(path, mask, 0);
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
        Result := Start(FileName, stringToFind, 1);
      end;
    end;
  end;
end;

procedure TFindFilesTask.FindFilesInDir(const Dir: string; SearchMasks: TStringList; const IsSearching: boolean; FilePaths: TStringList);
var
  SearchMask: string;
  SearchRec: TSearchRec;
begin
  if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SearchRec) = 0 then
  begin
    try
      repeat
        if not IsSearching then
          Exit; // Проверяем флаг остановки
        for SearchMask in SearchMasks do
        begin
          if MatchesMask(SearchRec.Name, SearchMask) then
            FilePaths.Add(IncludeTrailingPathDelimiter(Dir) + SearchRec.Name);
        end;
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;

  if not IsSearching then
    Exit; // Проверяем флаг остановки

  // Рекурсивный поиск в подкаталогах
  if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faDirectory, SearchRec) = 0 then
  begin
    try
      repeat
        if (SearchRec.Attr and faDirectory <> 0) and (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
        begin
          FindFilesInDir(IncludeTrailingPathDelimiter(Dir) + SearchRec.Name, SearchMasks, IsSearching, FilePaths);
        end;
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;
end;

function TFindFilesTask.GetFilePaths(AThread: TThread): TStringList;
var
  ResultTask: TResultTask;
begin
  Result := nil;
  ResultTask := FResultTaskList.FindResultTaskByThread(AThread);
  if Assigned(ResultTask) then
    Result := ResultTask.FilePaths;
end;

function TFindFilesTask.GetPositions(AThread: TThread): TList<integer>;
var
  ResultTask: TResultTask;
begin
  Result := nil;
  ResultTask := FResultTaskList.FindResultTaskByThread(AThread);
  if Assigned(ResultTask) then
    Result := ResultTask.Positions;
end;

function TFindFilesTask.GetTasks: TArray<TTaskInfo>;
begin
  SetLength(Result, 2);
  Result[0].Name := 'Поиск файлов';
  Result[0].Parameters := 'Каталог для поиска, расширение файлов';
  Result[1].Name := 'Поиск в файле';
  Result[1].Parameters := 'Файл, строка для поиска';
end;

function TFindFilesTask.Start(const Command, Param: string; operation: integer): TThread;
var
  ResultTask: TResultTask;
begin
  ResultTask := TResultTask.Create;
  if operation = 0 then
  begin
    ResultTask.SearchMasks.Delimiter := ';';
    ResultTask.SearchMasks.DelimitedText := Param;
    FRootPath := Command;
  end
    else
  begin
    FFileName := Command;
    FStringToFind := Param;
  end;
  Result := FThreadPool.Start(
  procedure
  begin
    if operation = 0 then
      FindFilesInDir(FRootPath, ResultTask.SearchMasks, ResultTask.IsSearching, ResultTask.FilePaths)
    else
      CountStringOccurrences(FFileName, FStringToFind, ResultTask.IsSearching, ResultTask.Positions);
    ResultTask.IsSearching := False;
  end
  );
  ResultTask.Thread := Result;
  FResultTaskList.Add(ResultTask);
end;

procedure TFindFilesTask.Stop(AThread: TThread);
var
  ResultTask: TResultTask;
begin
  ResultTask := FResultTaskList.FindResultTaskByThread(AThread);
  if Assigned(ResultTask) then
    ResultTask.IsSearching := false;
  FThreadPool.Stop(AThread);
end;

function TFindFilesTask.CheckRunning(AThread: TThread): boolean;
var
  ResultTask: TResultTask;
begin
  Result := false;
  ResultTask := FResultTaskList.FindResultTaskByThread(AThread);
  if Assigned(ResultTask) then
    Result := ResultTask.IsSearching;
end;

function TFindFilesTask.CountStringOccurrences(const FileName, StringToFind: string; const IsSearching: boolean; Positions: TList<integer>): integer;
var
  Stream: TFileStream;
  Buffer: array of Byte;
  BufferSize: Integer;
  BytesRead, searchStringLength: integer;
  CurrentPosition: Integer;
  SearchStrings: TStringList;
  SearchString: AnsiString;
  i, j: integer;
begin
  Result := 0;
  if Assigned(Positions) then
    Positions.Clear;

  // Разделяем строки поиска по запятой
  SearchStrings := TStringList.Create;
  try
    SearchStrings.Delimiter := ',';
    SearchStrings.StrictDelimiter := True;
    SearchStrings.DelimitedText := StringToFind;

    // Если список пустой, возвращаем 0
    if SearchStrings.Count = 0 then
      Exit;

    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      BufferSize := 4096; // Оптимальный размер буфера
      SetLength(Buffer, BufferSize);
      CurrentPosition := 0;

      while True do
      begin
        if not IsSearching then
          Exit; // Проверяем флаг остановки

        BytesRead := Stream.Read(Buffer[0], BufferSize);
        if BytesRead = 0 then
          Break;

        // Проверяем каждую строку поиска
        for j := 0 to SearchStrings.Count - 1 do
        begin
          SearchString := AnsiString(SearchStrings[j]);
          searchStringLength := Length(SearchString);

          // Ищем в буфере
          for i := 0 to BytesRead - searchStringLength do
          begin
            if CompareMem(@Buffer[i], PAnsiChar(SearchString), Length(SearchString)) then
            begin
              if Assigned(Positions) then
                Positions.Add(CurrentPosition + i);
              Inc(Result); // Увеличиваем счетчик
            end;
          end;
        end;

        CurrentPosition := CurrentPosition + BytesRead; // Обновляем текущую позицию
      end;
    finally
      Stream.Free;
    end;
  finally
    SearchStrings.Free;
  end;
end;

function CreateTaskProvider: IFileFinder;
begin
  Result := TFindFilesTask.Create;
end;


exports
  CreateTaskProvider;

{ TResultTask }

constructor TResultTask.Create;
begin
  inherited;
  FSearchMasks := TStringList.Create;
  FFilePaths := TStringList.Create;
  FIsSearching := true;
  FPositions := TList<integer>.Create;
  FThread := nil;
end;

destructor TResultTask.Destroy;
begin
  FreeAndNil(FSearchMasks);
  FreeAndNil(FFilePaths);
  FreeAndNil(FPositions);
  FThread := nil;
  inherited;
end;

{ TResultTaskList }

function TResultTaskList.FindResultTaskByThread(AThread: TThread): TResultTask;
var
  task: TResultTask;
begin
  Result := nil;
  for task in Self do
    if task.Thread = AThread then
    begin
      Result := task;
      exit;
    end;
end;

begin
end.
