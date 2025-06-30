unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, TaskApi,   VirtualTrees,  VirtualTrees.Types, VirtualTrees.Obj,
  cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters, dxCore,
  dxRibbonSkins, dxRibbonCustomizationForm, dxLayoutcxEditAdapters,
  dxLayoutContainer, cxContainer, cxEdit, dxCoreGraphics,
  VirtualTrees.BaseAncestorVCL, VirtualTrees.BaseTree, VirtualTrees.AncestorVCL,
  cxTextEdit, cxMaskEdit, cxButtonEdit, dxLayoutControl, cxClasses, dxBar,
  dxRibbon, cxSplitter, Generics.Collections, System.Actions, Vcl.ActnList,
  System.ImageList, Vcl.ImgList, cxImageList, Vcl.StdCtrls;

type
  TTaskOperation = (ttoNone, ttoFindFiles, ttoFindInFile, ttoShellExecute);
  TStateTaskOperation = (tstoNone, tstoRun, tstoStop, tstoFinish);
  TStateCallback = reference to function: boolean;

  TVSTTask = class(TBaseRecord)
  private
    FParams: string;
    FOperation: TTaskOperation;
    FCommand: string;
    FTaskInfoName: string;
    FTaskInfoParams: string;
  public
    constructor Create; override;
    property Command: string read FCommand write FCommand;
    property Params: string read FParams write FParams;
    property TaskInfoName: string read FTaskInfoName write FTaskInfoName;
    property TaskInfoParams: string read FTaskInfoParams write FTaskInfoParams;
    property Operation: TTaskOperation read FOperation write FOperation;
  end;

  TVSTRunTask = class(TBaseRecord)
  private
    FNeedToCheckRun: boolean;
    FState: TStateTaskOperation;
    FCommand: string;
    FTaskInfoName: string;
    FPositions: TList<integer>;
    FFilePaths: TStringList;
    FStateCallback: TStateCallback;
    FFinishCallback: TProc;
    FOperation: TTaskOperation;
    FRunningThread: TThread;
    FProcessID: DWORD;
    function GetState: TStateTaskOperation;
  public
    constructor Create; override;
    destructor Destroy; override;
    property Operation: TTaskOperation read FOperation write FOperation;
    property TaskInfoName: string read FTaskInfoName write FTaskInfoName;
    property Command: string read FCommand write FCommand;
    property State: TStateTaskOperation read GetState write FState;
    property FilePaths: TStringList read FFilePaths write FFilePaths;
    property Positions: TList<integer> read FPositions write FPositions;
    property StateCallback: TStateCallback read FStateCallback write FStateCallback;
    property FinishCallback: TProc read FFinishCallback write FFinishCallback;
    property RunningThread: TThread read FRunningThread write FRunningThread;
    property ProcessID: DWORD read FProcessID write FProcessID;
  end;

  TfrmRunTasks = class(TForm)
    rbMainTab1: TdxRibbonTab;
    rbMain: TdxRibbon;
    bmMain: TdxBarManager;
    lcRunTasksGroup_Root: TdxLayoutGroup;
    lcRunTasks: TdxLayoutControl;
    lgParams: TdxLayoutGroup;
    lgTasks: TdxLayoutGroup;
    beCommand: TcxButtonEdit;
    liCommand: TdxLayoutItem;
    edParams: TcxTextEdit;
    liParams: TdxLayoutItem;
    vstTasks: TVirtualStringTree;
    liTasks: TdxLayoutItem;
    cxSplitter1: TcxSplitter;
    vstRunTask: TVirtualStringTree;
    bActions: TdxBar;
    ilBig: TcxImageList;
    ilSmall: TcxImageList;
    alRunTasks: TActionList;
    acRun: TAction;
    acStop: TAction;
    btnRunTask: TdxBarLargeButton;
    btnStopTask: TdxBarLargeButton;
    odBinFilesDialog: TOpenDialog;
    cxSplitter2: TcxSplitter;
    mResult: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure vstTasksGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure vstTasksChange(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure FormShow(Sender: TObject);
    procedure beCommandKeyPress(Sender: TObject; var Key: Char);
    procedure vstRunTaskGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure acRunExecute(Sender: TObject);
    procedure acStopExecute(Sender: TObject);
    procedure alRunTasksUpdate(Action: TBasicAction; var Handled: Boolean);
    procedure beCommandPropertiesButtonClick(Sender: TObject;
      AButtonIndex: Integer);
    procedure vstRunTaskChange(Sender: TBaseVirtualTree; Node: PVirtualNode);
  private
    { Private declarations }
    FFileFinder: IFileFinder;
    FShellExecuter: IShellExecuter;
    FCurrentOperation: TTaskOperation;
    FDirectory: string;
    procedure AddTask(AOperation: TTaskOperation; ATaskInfoName, ATaskInfoParams: string);
    procedure AddRunTask;
    procedure FillTasks;
  public
    { Public declarations }
  end;

var
  frmRunTasks: TfrmRunTasks;

implementation

uses ShellApi, ShlObj, Winapi.ActiveX;

const
  TStringStateOperations: array[TStateTaskOperation] of string = ('', 'Запущено', 'Остановлено', 'Завершено');

{$R *.dfm}

function SelectDirectoryDialog(const Caption: string; var Directory: string): Boolean;
var
  BrowseInfo: TBrowseInfo;
  Buffer: array[0..MAX_PATH] of Char;
  PIDL: PItemIDList;
begin
  Result := False;

  FillChar(BrowseInfo, SizeOf(BrowseInfo), 0);
  with BrowseInfo do
  begin
    hwndOwner := 0; // можно указать окно, если есть
    pszDisplayName := Buffer;
    lpszTitle := PChar(Caption);
    lParam := integer(PChar(Directory));
    ulFlags := BIF_RETURNONLYFSDIRS or BIF_USENEWUI;
  end;

  PIDL := SHBrowseForFolder(BrowseInfo);
  if Assigned(PIDL) then
  begin
    if SHGetPathFromIDList(PIDL, Buffer) then
    begin
      Directory := Buffer;
      Result := True;
    end;
    CoTaskMemFree(PIDL);
  end;
end;

procedure TfrmRunTasks.acRunExecute(Sender: TObject);
begin
  AddRunTask;
end;

procedure TfrmRunTasks.acStopExecute(Sender: TObject);
var
  RunTask: TVSTRunTask;
begin
  RunTask := vstRunTask.CurrentObj<TVSTRunTask>;
  if Assigned(RunTask) and (RunTask.Operation in [ttoFindFiles, ttoFindInFile]) then
    FFileFinder.Stop(RunTask.RunningThread);
end;

procedure TfrmRunTasks.AddRunTask;
var
  Task: TVSTTask;
  TaskCommand, TaskParams: string;
  RunThread: TThread;
  RunProcessID: DWORD;
  isParamsCorrect: boolean;
begin
  if FCurrentOperation <> ttoNone then
  begin
    Task := vstTasks.CurrentObj<TVSTTask>;
    if Assigned(Task) then
    begin
      TaskCommand := beCommand.Text;
      TaskParams := edParams.Text;
      RunThread := nil;
      RunProcessID := 0;
      isParamsCorrect := true;
      case FCurrentOperation of
        ttoFindFiles,
        ttoFindInFile: RunThread := FFileFinder.ExecuteTask(Task.TaskInfoName, TaskCommand + ',' + TaskParams);
        ttoShellExecute: RunProcessID := FShellExecuter.ExecuteShellCommand(TaskCommand);
      end;
      if isParamsCorrect then
      begin
        with vstRunTask.obj<TVSTRunTask> do
        begin
          TaskInfoName := Task.TaskInfoName;
          if FCurrentOperation = ttoShellExecute then
          begin
            Command := TaskCommand;
            ProcessID := RunProcessID;
            StateCallback :=
            function: boolean
            begin
              Result := FShellExecuter.WaitForCommandCompletion(ProcessID, 1);
            end;
            State := tstoRun;
          end
            else
          begin
            Operation := FCurrentOperation;
            RunningThread := RunThread;
            Command := TaskCommand + ',' + TaskParams;
            StateCallback :=
            function: boolean
            begin
              Result := FFileFinder.CheckRunning(RunningThread);
            end;
            FinishCallback :=
            procedure
            begin
              if Operation = ttoFindFiles then
              begin
                if Assigned(FFileFinder.GetFilePaths(RunningThread)) then
                  FFilePaths.AddStrings(FFileFinder.GetFilePaths(RunningThread))
              end
              else
              begin
                if Assigned(FFileFinder.GetPositions(RunningThread)) then
                  FPositions.AddRange(FFileFinder.GetPositions(RunningThread));
              end;
            end;
            State := tstoRun;
          end;
        end;
      end;
    end;
  end;
end;

procedure TfrmRunTasks.AddTask(AOperation: TTaskOperation; ATaskInfoName,
  ATaskInfoParams: string);
begin
  with vstTasks.obj<TVSTTask> do
  begin
    Operation := AOperation;
    TaskInfoName := ATaskInfoName;
    TaskInfoParams := ATaskInfoParams;
  end;
end;

procedure TfrmRunTasks.alRunTasksUpdate(Action: TBasicAction; var Handled: Boolean);
var
  CorrectCurrentOperation, CorrectCommand, IsRunning: boolean;
  RunTask: TVSTRunTask;
begin
  CorrectCurrentOperation := (FCurrentOperation <> ttoNone);
  CorrectCommand := (beCommand.Text <> '');
  RunTask := vstRunTask.CurrentObj<TVSTRunTask>;
  if Assigned(RunTask) then
    IsRunning := RunTask.State = tstoRun
  else
    IsRunning := false;
  case FCurrentOperation of
    ttoFindFiles,
    ttoFindInFile:
      begin
        CorrectCommand := CorrectCommand and (edParams.Text <> '');
      end;
  end;
  acRun.Enabled := CorrectCurrentOperation and CorrectCommand;
  acStop.Enabled := CorrectCurrentOperation and CorrectCommand and IsRunning;
end;

procedure TfrmRunTasks.beCommandKeyPress(Sender: TObject; var Key: Char);
begin
  if FCurrentOperation <> ttoShellExecute then
    Key := #0;
end;

procedure TfrmRunTasks.beCommandPropertiesButtonClick(Sender: TObject;
  AButtonIndex: Integer);
begin
  if FCurrentOperation in [ttoFindFiles, ttoFindInFile] then
  begin
    if FCurrentOperation = ttoFindFiles then
    begin
      if SelectDirectoryDialog('Выберите каталог для сканирования', FDirectory) then
        beCommand.Text := FDirectory;
    end
      else
    begin
      if odBinFilesDialog.Execute then
        beCommand.Text := odBinFilesDialog.FileName;
    end;
  end;
end;

procedure TfrmRunTasks.FillTasks;
var
  taskInfo: TTaskInfo;
begin
  vstTasks.BeginUpdate;
  try
    vstTasks.Clear;
    if assigned(FFileFinder) then
    begin
      for taskInfo in FFileFinder.GetTasks do
      begin
        if taskInfo.Name = 'Поиск файлов' then
          AddTask(ttoFindFiles, taskInfo.Name, taskInfo.Parameters)
        else
          AddTask(ttoFindInFile, taskInfo.Name, taskInfo.Parameters)
      end;
    end;
    if assigned(FShellExecuter) then
    begin
      for taskInfo in FShellExecuter.GetTasks do
        AddTask(ttoShellExecute, taskInfo.Name, taskInfo.Parameters);
    end;
  finally
    vstTasks.EndUpdate;
  end;
end;

procedure TfrmRunTasks.FormCreate(Sender: TObject);
begin
  FFileFinder := LoadTaskDLL('FindDLL.dll') as IFileFinder;
  FShellExecuter := LoadTaskDLL('ExecuteDLL.dll') as IShellExecuter;
  FCurrentOperation := ttoNone;
  vstTasks.NodeDataSize := SizeOf(TVSTTask);
  vstRunTask.NodeDataSize := SizeOf(TVSTRunTask);
  FDirectory := ExtractFilePath(Application.ExeName);
end;

procedure TfrmRunTasks.FormShow(Sender: TObject);
begin
  FillTasks;
end;

procedure TfrmRunTasks.vstRunTaskChange(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
var
  RunTask: TVSTRunTask;
  i: integer;
begin
  mResult.Lines.Clear;
  RunTask := Sender.obj<TVSTRunTask>(Node, false);
  if Assigned(RunTask) and (RunTask.Operation in [ttoFindFiles, ttoFindInFile]) then
  begin
    with mResult.Lines do
    begin
      Add('Операция: ' + RunTask.TaskInfoName);
      Add('Команда: ' + RunTask.Command);
      if RunTask.Operation = ttoFindFiles then
      begin
        Add('Найдено: ' + IntToStr(RunTask.FilePaths.Count));
        AddStrings(RunTask.FilePaths);
      end
        else if RunTask.Operation = ttoFindInFile then
      begin
        Add('Найдено: ' + IntToStr(RunTask.Positions.Count));
        for i := 0 to RunTask.Positions.Count - 1 do
          Add(IntToStr(RunTask.Positions[i]));
      end;
    end;
  end;
end;

procedure TfrmRunTasks.vstRunTaskGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
var
  RunTask: TVSTRunTask;
begin
  CellText := '';
  RunTask := Sender.obj<TVSTRunTask>(Node, false);
  if Assigned(RunTask) then
  begin
    case column of
      0: CellText := RunTask.TaskInfoName;
      1: CellText := RunTask.Command;
      2: CellText := TStringStateOperations[RunTask.State];
    end;
  end;
end;

procedure TfrmRunTasks.vstTasksChange(Sender: TBaseVirtualTree; Node: PVirtualNode);
var
  Task: TVSTTask;
begin
  FCurrentOperation := ttoNone;
  Task := Sender.obj<TVSTTask>(Node, false);
  if Assigned(Task) then
  begin
    FCurrentOperation := task.Operation;
    lgParams.Visible := true;
    liParams.Visible := true;
    lgParams.CaptionOptions.Text := 'Параметры операции: ' + task.TaskInfoName;
    case task.Operation of
      ttoFindFiles:
        begin
          liCommand.CaptionOptions.Text := 'Каталог для поиска';
          liParams.CaptionOptions.Text := 'Расширение файлов';
        end;
      ttoFindInFile:
        begin
          liCommand.CaptionOptions.Text := 'Файл';
          liParams.CaptionOptions.Text := 'Строка для поиска';
        end;
      ttoShellExecute:
        begin
          liCommand.CaptionOptions.Text := 'Команда';
          liParams.Visible := false;
        end;
    end;
    beCommand.Text := task.Command;
    edParams.Text := task.Params;
  end;
end;

procedure TfrmRunTasks.vstTasksGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
var
  Task: TVSTTask;
begin
  CellText := '';
  Task := Sender.obj<TVSTTask>(Node, false);
  if Assigned(Task) then
  begin
    case Column of
      0: CellText := Task.TaskInfoName;
      1: CellText := Task.TaskInfoParams;
    end;
  end;
end;

{ TVSTTask }

constructor TVSTTask.Create;
begin
  inherited;
  FOperation := ttoNone;
  FCommand := '';
  FParams := '';
  FTaskInfoName := '';
  FTaskInfoParams := '';
end;

{ TVSTRunTask }

constructor TVSTRunTask.Create;
begin
  inherited;
  FOperation := ttoNone;
  FFilePaths := TStringList.Create;
  FPositions := TList<integer>.Create;
  FState := tstoNone;
  FTaskInfoName := '';
  FCommand := '';
  FNeedToCheckRun := true;
  FStateCallback := nil;
  FFinishCallback := nil;
  FRunningThread := nil;
  FProcessID := 0;
end;

destructor TVSTRunTask.Destroy;
begin
  FreeAndNil(FFilePaths);
  FreeAndNil(FPositions);
  inherited;
end;

function TVSTRunTask.GetState: TStateTaskOperation;
var
  CallbackResult: boolean;
begin
  if Assigned(FStateCallback) and FNeedToCheckRun and (FState <> tstoNone) then
  begin
    CallbackResult := FStateCallback();
    if CallbackResult then
      FState := tstoRun
    else begin
      FState := tstoFinish;
      FNeedToCheckRun := false;
      if Assigned(FFinishCallback) then
        FFinishCallback();
    end;
  end;
  Result := FState;
end;

end.
