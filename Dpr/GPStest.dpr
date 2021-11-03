program GPStest;

uses
  Forms,
  MainF {MainForm},
  SatF {SatForm};

{$R *.res}

begin
  Application.Initialize;

  Application.Title := 'GPStest';
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TSatForm, SatForm);

  Application.Run;
end.
