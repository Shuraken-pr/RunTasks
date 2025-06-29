program RunTasks;

uses
  Vcl.Forms,
  Main in 'Main.pas' {frmRunTasks},
  TaskAPI in '..\Common\TaskAPI.pas',
  VirtualTrees.Obj in '..\Common\VirtualTrees.Obj.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmRunTasks, frmRunTasks);
  Application.Run;
end.
