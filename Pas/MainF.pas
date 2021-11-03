unit MainF;

interface

uses
  Windows,
  SysUtils,
  SyncObjs,
  StdCtrls,
  Spin,
  Forms,
  Dialogs,
  Controls,
  CheckLst,
  Classes,
  GPSdataU,
  COMportU;

type
  TMainForm = class(TForm)
    AltitudeLabel            : TLabel;
    CorrectCommandEdit       : TEdit;
    DataViewCheckListBox     : TCheckListBox;
    DataViewLabel            : TLabel;
    DataViewMemo             : TMemo;
    GMTDateLabel             : TLabel;
    GMTTimeLabel             : TLabel;
    InitEricssonF3507gButton : TButton;
    LatitudeLabel            : TLabel;
    LogDataCheckBox          : TCheckBox;
    LongitudeLabel           : TLabel;
    OpenButton               : TButton;
    PortLabel                : TLabel;
    PortSpinEdit             : TSpinEdit;
    SatellitesButton         : TButton;
    SatellitesListBox        : TListBox;
    SatFixLabel              : TLabel;
    TalkerCaptionLabel       : TLabel;
    TalkerValueLabel         : TLabel;
    WrapDataViewCheckBox     : TCheckBox;
    WrongCommandEdit         : TEdit;
    LocalLabel: TLabel;

    procedure FormCreate(Sender : TObject);
    procedure FormDestroy(Sender : TObject);
    procedure LogDataCheckBoxClick(Sender : TObject);
    procedure OpenButtonClick(Sender : TObject);
    procedure SatellitesButtonClick(Sender : TObject);
    procedure InitEricssonF3507gButtonClick(Sender: TObject);
  private
    { Private-Deklarationen }
    FBaudRate        : LongInt;
    FCOMport         : TCOMport;
    FCriticalSection : TCriticalSection;
    FFile            : TextFile;
    FGPSdata         : TGPSdata;

    procedure GGAdata(const ASender : TObject; const ATalkerID : String; const AData : TGGAdata);
    procedure GLLdata(const ASender : TObject; const ATalkerID : String; const AData : TGLLdata);
    procedure GSAdata(const ASender : TObject; const ATalkerID : String; const AData : TGSAdata);
    procedure GSVData(const ASender : TObject; const ATalkerID : String; const AData : TGSVdata);
    procedure RMCdata(const ASender : TObject; const ATalkerID : String; const AData : TRMCdata);
    procedure VTGdata(const ASender : TObject; const ATalkerID : String; const AData : TVTGdata);
    procedure ZDAdata(const ASender : TObject; const ATalkerID : String; const AData : TZDAdata);

    procedure AddLine(const AString : String);
    procedure ShowLine(const ASender : TObject; const AString : String);
    procedure WrongCheckSum(const ASender : TObject; const ALine : String);

    procedure SetupConnection(const ASender : TObject; const ACOMhandle : THandle; var AConfig : TCommConfig; var ATimeouts : TCommTimeouts);
  public
    { Public-Deklarationen }
  end;

var
  MainForm : TMainForm;

const
  CMaxLines = 1000;

  CGGAindex = 0;
  CGLLindex = 1;
  CGSAindex = 2;
  CGSVindex = 3;
  CRMCindex = 4;
  CVTGindex = 5;
  CZDAindex = 6;

implementation

uses
  SatF;

{$R *.dfm}

procedure TMainForm.FormCreate(Sender : TObject);
begin
  FCriticalSection := TCriticalSection.Create;

  FCOMport := TCOMport.Create(0);
  FCOMport.ClearBufferOnOpen  := true;
  FCOMport.FlushBufferOnClose := true;
  FCOMport.OnSetupConnection  := SetupConnection;
  FCOMport.ReadOnly           := true;
  FCOMport.ShowSetupDialog    := true;
  FCOMport.Threaded           := true;

  FGPSdata := TGPSdata.Create;
  FGPSdata.ProceedWithWrongChecksum := true;
  FGPSdata.ValidateChecksum         := true;
  FGPSdata.OnBeforeSplitLine        := ShowLine;
  FGPSdata.OnGGAdata                := GGAdata;
  FGPSdata.OnGLLdata                := GLLdata;
  FGPSdata.OnGSAdata                := GSAdata;
  FGPSdata.OnGSVData                := GSVData;
  FGPSdata.OnInitInput              := ShowLine;
  FGPSdata.OnInitOutput             := ShowLine;
  FGPSdata.OnRMCdata                := RMCdata;
  FGPSdata.OnVTGdata                := VTGdata;
  FGPSdata.OnWrongChecksum          := WrongCheckSum;
  FGPSdata.OnZDAdata                := ZDAdata;

  FBaudRate := -1;
  if (ParamCount > 0) then
  begin
    if not(TryStrToInt(ParamStr(1), FBaudRate)) then
      FBaudRate := -1;
  end;
end;

procedure TMainForm.FormDestroy(Sender : TObject);
begin
  FGPSdata.Free;
  FCOMport.Free;
  FCriticalSection.Free;

  if LogDataCheckBox.Checked then
  begin
    Flush(FFile);
    CloseFile(FFile);
  end;
end;

procedure TMainForm.LogDataCheckBoxClick(Sender : TObject);
begin
  if LogDataCheckBox.Checked then
  begin
    AssignFile(FFile, ExtractFilePath(Application.ExeName) + 'GPStest.log');

    if (FileExists(ExtractFilePath(Application.ExeName) + 'GPStest.log')) then
    begin
      Append(FFile);
      WriteLn(FFile, '');
    end
    else
      Rewrite(FFile);

    WriteLn(FFile, '{' + DateTimeToStr(Now) + '}');
  end
  else
  begin
    Flush(FFile);
    CloseFile(FFile);
  end;
end;

procedure TMainForm.OpenButtonClick(Sender : TObject);
begin
  if (OpenButton.Tag = 0) then
  begin
    FCOMport.Number := PortSpinEdit.Value;
    FCOMport.OpenConnection;

    FGPSdata.COMport := FCOMport;

    OpenButton.Caption := '&Close';
    OpenButton.Tag     := 1;
  end
  else
  begin
    FCOMport.CloseConnection;

    OpenButton.Caption := 'Open';
    OpenButton.Tag     := 0;

    if SatForm.Showing then
      SatForm.Close;
  end;

  InitEricssonF3507gButton.Enabled := (OpenButton.Tag <> 0);
  PortSpinEdit.Enabled             := (OpenButton.Tag = 0);
  SatellitesButton.Enabled         := (OpenButton.Tag <> 0);
end;

procedure TMainForm.SatellitesButtonClick(Sender : TObject);
begin
  SatForm.Show;
end;

procedure TMainForm.GGAdata(const ASender : TObject; const ATalkerID : String; const AData: TGGAdata);
begin
  FCriticalSection.Enter;
  try
    TalkerValueLabel.Caption := ATalkerID + ' (' + TGPSdata.TalkerIDToDescription(ATalkerID) + ')';

    GMTTimeLabel.Caption := 'Time: ' + TimeToStr(TGPSdata.TimeStringToTime(AData.UTC)) + ' (GMT)';

    AltitudeLabel.Caption  := 'Altitude: ' + AData.AntennaAltitude + ' ' + AData.AntennaAltitudeUnit + ' (' + AData.GeoidalSeparation + ' ' + AData.GeoidalSeparationUnit + ')';
    LatitudeLabel.Caption  := 'Latitutde: ' + AData.Latitude + ' ' + AData.Lat_NorthSouth;
    LongitudeLabel.Caption := 'Longitude: ' + AData.Longitude + ' ' + AData.Lon_EastWest;

    if DataViewCheckListBox.Checked[CGGAindex] then
    begin
      if ((DataViewMemo.Lines.Count > CMaxLines) and WrapDataViewCheckBox.Checked) then
        DataViewMemo.Lines.Clear;

      AddLine('Command: ' + AData.Command);
      AddLine('UTC: ' + AData.UTC);
      AddLine('Latitude: ' + AData.Latitude);
      AddLine('Latitude North/South: ' + AData.Lat_NorthSouth + ' (' + TGPSdata.DirectionToDescription(AData.Lat_NorthSouth) + ')');
      AddLine('Longitude: ' + AData.Longitude);
      AddLine('Longitude East/West: ' + AData.Lon_EastWest + ' (' + TGPSdata.DirectionToDescription(AData.Lon_EastWest) + ')');
      AddLine('Quality Indicator: ' + AData.QualityIndicator + ' (' + TGPSdata.GPSQualityIndicatorToDescription(AData.QualityIndicator) + ')');
      AddLine('Satellite Count: ' + AData.SatelliteCount);
      AddLine('Horizontal Dilution: ' + AData.HorizontalDilution);
      AddLine('Antenna Altitude: ' + AData.AntennaAltitude);
      AddLine('Antenna Altitude Unit: ' + AData.AntennaAltitudeUnit);
      AddLine('Geoidal Separation: ' + AData.GeoidalSeparation);
      AddLine('Geoidal Separation Unit: ' + AData.GeoidalSeparationUnit);
      AddLine('Differential Data Age: ' + AData.DifferentialDataAge);
      AddLine('Differential Reference Station ID: ' + AData.DifferentialReferenceStationID);
      AddLine('Checksum: ' + AData.Checksum);
      AddLine('----------');
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TMainForm.GLLdata(const ASender : TObject; const ATalkerID : String; const AData: TGLLdata);
begin
  FCriticalSection.Enter;
  try
    TalkerValueLabel.Caption := ATalkerID + ' (' + TGPSdata.TalkerIDToDescription(ATalkerID) + ')';

    GMTTimeLabel.Caption := 'Time: ' + TimeToStr(TGPSdata.TimeStringToTime(AData.UTC)) + ' (GMT)';

    LatitudeLabel.Caption  := 'Latitutde: ' + AData.Latitude + ' ' + AData.Lat_NorthSouth;
    LongitudeLabel.Caption := 'Longitude: ' + AData.Longitude + ' ' + AData.Lon_EastWest;

    if DataViewCheckListBox.Checked[CGLLindex] then
    begin
      if ((DataViewMemo.Lines.Count > CMaxLines) and WrapDataViewCheckBox.Checked) then
        DataViewMemo.Lines.Clear;

      AddLine('Command: ' + AData.Command);
      AddLine('Latitude: ' + AData.Latitude);
      AddLine('Latitude North/South: ' + AData.Lat_NorthSouth + ' (' + TGPSdata.DirectionToDescription(AData.Lat_NorthSouth) + ')');
      AddLine('Longitude: ' + AData.Longitude);
      AddLine('Longitude East/West: ' + AData.Lon_EastWest + ' (' + TGPSdata.DirectionToDescription(AData.Lon_EastWest) + ')');
      AddLine('UTC: ' + AData.UTC);
      AddLine('Status: ' + AData.Status + ' (' + TGPSdata.StatusToDescription(AData.Status) + ')');
      AddLine('Mode Indicator: ' + AData.ModeIndicator + ' (' + TGPSdata.FAAModeIndicatorToDescription(AData.ModeIndicator) + ')');
      AddLine('Checksum: ' + AData.Checksum);
      AddLine('----------');
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TMainForm.GSAdata(const ASender : TObject; const ATalkerID : String; const AData: TGSAdata);
  function DoIntToStr(const AInteger : LongInt; const AMinLength : Byte) : String;
  begin
    Result := IntToStr(AInteger);
    while (Length(Result) < AMinLength) do
      Result := '0' + Result;
  end;

  function IsFixSatellite(const AData : TGSAdata; const AID : LongInt) : Boolean;
    function DoStrToInt(const AString : String) : LongInt;
    begin
      if not(TryStrToInt(AString, Result)) then
        Result := -1;
    end;
  begin
    Result := (DoStrToInt(AData.FixSatelliteID1) = AID) or
              (DoStrToInt(AData.FixSatelliteID2) = AID) or
              (DoStrToInt(AData.FixSatelliteID3) = AID) or
              (DoStrToInt(AData.FixSatelliteID4) = AID) or
              (DoStrToInt(AData.FixSatelliteID5) = AID) or
              (DoStrToInt(AData.FixSatelliteID6) = AID) or
              (DoStrToInt(AData.FixSatelliteID7) = AID) or
              (DoStrToInt(AData.FixSatelliteID8) = AID) or
              (DoStrToInt(AData.FixSatelliteID9) = AID) or
              (DoStrToInt(AData.FixSatelliteID10) = AID) or
              (DoStrToInt(AData.FixSatelliteID11) = AID) or
              (DoStrToInt(AData.FixSatelliteID12) = AID);
  end;
var
  LFixes : array of String;
  LIndex : LongInt;
begin
  FCriticalSection.Enter;
  try
    TalkerValueLabel.Caption := ATalkerID + ' (' + TGPSdata.TalkerIDToDescription(ATalkerID) + ')';

    SatFixLabel.Caption := AnsiUpperCase(TGPSdata.ModeToDescription(AData.Mode));
    for LIndex := 0 to Pred(SatellitesListBox.Items.Count) do
    begin
      SatellitesListBox.Items[LIndex] := DoIntToStr(LongInt(SatellitesListBox.Items.Objects[LIndex]), 2);
      if IsFixSatellite(AData, LongInt(SatellitesListBox.Items.Objects[LIndex])) then
        SatellitesListBox.Items[LIndex] := SatellitesListBox.Items[LIndex] + ' - FIX';
    end;

    SetLength(LFixes, 12);
    LFixes[0] := AData.FixSatelliteID1;
    LFixes[1] := AData.FixSatelliteID2;
    LFixes[2] := AData.FixSatelliteID3;
    LFixes[3] := AData.FixSatelliteID4;
    LFixes[4] := AData.FixSatelliteID5;
    LFixes[5] := AData.FixSatelliteID6;
    LFixes[6] := AData.FixSatelliteID7;
    LFixes[7] := AData.FixSatelliteID8;
    LFixes[8] := AData.FixSatelliteID9;
    LFixes[9] := AData.FixSatelliteID10;
    LFixes[10] := AData.FixSatelliteID11;
    LFixes[11] := AData.FixSatelliteID12;
    SatForm.SetFixes(LFixes);

    if DataViewCheckListBox.Checked[CGSAindex] then
    begin
      if ((DataViewMemo.Lines.Count > CMaxLines) and WrapDataViewCheckBox.Checked) then
        DataViewMemo.Lines.Clear;

      AddLine('Command: ' + AData.Command);
      AddLine('Selection Mode: ' + AData.SelectionMode + ' (' + TGPSdata.SelectionModeToDescription(AData.SelectionMode) + ')');
      AddLine('Mode: ' + AData.Mode + ' (' + TGPSdata.ModeToDescription(AData.Mode) + ')');
      AddLine('Fix Satelitte ID 1: ' + AData.FixSatelliteID1);
      AddLine('Fix Satelitte ID 2: ' + AData.FixSatelliteID2);
      AddLine('Fix Satelitte ID 3: ' + AData.FixSatelliteID3);
      AddLine('Fix Satelitte ID 4: ' + AData.FixSatelliteID4);
      AddLine('Fix Satelitte ID 5: ' + AData.FixSatelliteID5);
      AddLine('Fix Satelitte ID 6: ' + AData.FixSatelliteID6);
      AddLine('Fix Satelitte ID 7: ' + AData.FixSatelliteID7);
      AddLine('Fix Satelitte ID 8: ' + AData.FixSatelliteID8);
      AddLine('Fix Satelitte ID 9: ' + AData.FixSatelliteID9);
      AddLine('Fix Satelitte ID 10: ' + AData.FixSatelliteID10);
      AddLine('Fix Satelitte ID 11: ' + AData.FixSatelliteID11);
      AddLine('Fix Satelitte ID 12: ' + AData.FixSatelliteID12);
      AddLine('PDOP: ' + AData.PDOP);
      AddLine('HDOP: ' + AData.HDOP);
      AddLine('VDOP: ' + AData.VDOP);
      AddLine('Checksum: ' + AData.Checksum);
      AddLine('----------');
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TMainForm.GSVData(const ASender : TObject; const ATalkerID : String; const AData: TGSVdata);
var
  LIndex : LongInt;
begin
  FCriticalSection.Enter;
  try
    TalkerValueLabel.Caption := ATalkerID + ' (' + TGPSdata.TalkerIDToDescription(ATalkerID) + ')';

    if (AData.MessageIndex = '1') then
      SatellitesListBox.Clear;

    for Lindex := 0 to Pred(Length(AData.Satellites)) do
    begin
      if (SatellitesListBox.Items.IndexOfObject(TObject(StrToInt(AData.Satellites[LIndex].PRN))) < 0) then
        SatellitesListBox.Items.AddObject(AData.Satellites[LIndex].PRN, TObject(StrToInt(AData.Satellites[LIndex].PRN)));
    end;
    SatForm.SetSatellites(AData.Satellites, StrToInt(AData.MessageIndex));

    if DataViewCheckListBox.Checked[CGSVindex] then
    begin
      if ((DataViewMemo.Lines.Count > CMaxLines) and WrapDataViewCheckBox.Checked) then
        DataViewMemo.Lines.Clear;

      AddLine('Command: ' + AData.Command);
      AddLine('Message Count: ' + AData.MessageCount);
      AddLine('Message Index: ' + AData.MessageIndex);
      AddLine('Satellite Count: ' + AData.SatelliteCount);

      for LIndex := 0 to Pred(Length(AData.Satellites)) do
      begin
        AddLine('>> Satellite ' + IntToStr(Succ(LIndex)) + '/' + IntToStr(Length(AData.Satellites)) + '/' + AData.SatelliteCount + ' <<');
        AddLine('PRN: ' + AData.Satellites[LIndex].PRN);
        AddLine('Elevation: ' + AData.Satellites[LIndex].Elevation);
        AddLine('Azimuth: ' + AData.Satellites[LIndex].Azimuth);
        AddLine('SNR: ' + AData.Satellites[LIndex].SNR);
      end;

      AddLine('Checksum: ' + AData.Checksum);
      AddLine('----------');
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TMainForm.RMCdata(const ASender : TObject; const ATalkerID : String; const AData: TRMCdata);
begin
  FCriticalSection.Enter;
  try
    TalkerValueLabel.Caption := ATalkerID + ' (' + TGPSdata.TalkerIDToDescription(ATalkerID) + ')';

    GMTDateLabel.Caption := 'Date: ' + DateToStr(TGPSdata.DateStringToDate(AData.Date)) + ' (GMT)';
    GMTTimeLabel.Caption := 'Time: ' + TimeToStr(TGPSdata.TimeStringToTime(AData.UTC)) + ' (GMT)';

    LatitudeLabel.Caption  := 'Latitutde: ' + AData.Latitude + ' ' + AData.Lat_NorthSouth;
    LongitudeLabel.Caption := 'Longitude: ' + AData.Longitude + ' ' + AData.Lon_EastWest;

    if DataViewCheckListBox.Checked[CRMCindex] then
    begin
      if ((DataViewMemo.Lines.Count > CMaxLines) and WrapDataViewCheckBox.Checked) then
        DataViewMemo.Lines.Clear;

      AddLine('Command: ' + AData.Command);
      AddLine('UTC: ' + AData.UTC);
      AddLine('Status: ' + AData.Status + ' (' + TGPSdata.StatusToDescription(AData.Status) + ')');
      AddLine('Latitude: ' + AData.Latitude);
      AddLine('Latitude North/South: ' + AData.Lat_NorthSouth + ' (' + TGPSdata.DirectionToDescription(AData.Lat_NorthSouth) + ')');
      AddLine('Longitude: ' + AData.Longitude);
      AddLine('Longitude East/West: ' + AData.Lon_EastWest + ' (' + TGPSdata.DirectionToDescription(AData.Lon_EastWest) + ')');
      AddLine('Speed: ' + AData.Speed);
      AddLine('Track Correction: ' + AData.TrackCorrection);
      AddLine('Date: ' + AData.Date);
      AddLine('Magnetic Variation: ' + AData.MagneticVariation);
      AddLine('Magnetic Variation East/West: ' + AData.Var_EastWest);
      AddLine('Mode Indicator: ' + AData.ModeIndicator + ' (' + TGPSdata.FAAModeIndicatorToDescription(AData.ModeIndicator) + ')');
      AddLine('Checksum: ' + AData.Checksum);
      AddLine('----------');
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TMainForm.VTGdata(const ASender : TObject; const ATalkerID : String; const AData: TVTGdata);
begin
  FCriticalSection.Enter;
  try
    TalkerValueLabel.Caption := ATalkerID + ' (' + TGPSdata.TalkerIDToDescription(ATalkerID) + ')';

    if DataViewCheckListBox.Checked[CVTGindex] then
    begin
      if ((DataViewMemo.Lines.Count > CMaxLines) and WrapDataViewCheckBox.Checked) then
        DataViewMemo.Lines.Clear;

      AddLine('Command: ' + AData.Command);
      AddLine('Track Degrees (1): ' + AData.TrackDegrees1);
      AddLine('True: ' + AData.True + ' (True)');
      AddLine('Track Degrees (2): ' + AData.TrackDegrees2);
      AddLine('Magnetic: ' + AData.Magnetic + ' (Magnetic)');
      AddLine('Speed Knots: ' + AData.SpeedKnots);
      AddLine('Speed Knots Unit: ' + AData.SpeedKnotsUnit + ' (Knots)');
      AddLine('Speed KM/h: ' + AData.SpeedKpH);
      AddLine('Speed KM/h Unit: ' + AData.SpeedKpHUnit + ' (KM/h)');
      AddLine('Mode Indicator: ' + AData.ModeIndicator + ' (' + TGPSdata.FAAModeIndicatorToDescription(AData.ModeIndicator) + ')');
      AddLine('Checksum: ' + AData.Checksum);
      AddLine('----------');
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TMainForm.ZDAdata(const ASender : TObject; const ATalkerID : String; const AData: TZDAdata);
begin
  FCriticalSection.Enter;
  try
    TalkerValueLabel.Caption := ATalkerID + ' (' + TGPSdata.TalkerIDToDescription(ATalkerID) + ')';

    LocalLabel.Caption := 'Local: ' + AData.LocalZoneDescriptor + ':' + AData.LocalZoneMinutesDescriptor;

    if DataViewCheckListBox.Checked[CZDAindex] then
    begin
      if ((DataViewMemo.Lines.Count > CMaxLines) and WrapDataViewCheckBox.Checked) then
        DataViewMemo.Lines.Clear;

      AddLine('Command: ' + AData.Command);
      AddLine('UTC: ' + AData.UTC);
      AddLine('Day: ' + AData.Day);
      AddLine('Month: ' + AData.Month);
      AddLine('Year: ' + AData.Year);
      AddLine('Local Zone Descriptor: ' + AData.LocalZoneDescriptor);
      AddLine('Local Zone Minutes Descriptor: ' + AData.LocalZoneMinutesDescriptor);
      AddLine('Checksum: ' + AData.Checksum);
      AddLine('----------');
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TMainForm.AddLine(const AString: String);
begin
  DataViewMemo.Lines.Add(AString);
end;

procedure TMainForm.ShowLine(const ASender : TObject; const AString: String);
begin
  CorrectCommandEdit.Text := AString;

  if (LogDataCheckBox.Checked) then
    WriteLn(FFile, '[' + DateTimeToStr(Now) + ']' + AString);
end;

procedure TMainForm.WrongCheckSum(const ASender : TObject; const ALine: String);
begin
  WrongCommandEdit.Text := ALine;
end;

procedure TMainForm.InitEricssonF3507gButtonClick(Sender: TObject);
begin
  if FCOMport.IsOpen then
  begin
    if FGPSdata.InitEricssonF3507g then
      ShowMessage('Initializing your Ericsson F3507g has been SUCCESSFUL')
    else
      ShowMessage('Initializing your Ericsson F3507g has NOT been SUCCESSFUL');

    InitEricssonF3507gButton.Enabled := false;
  end;
end;

procedure TMainForm.SetupConnection(const ASender : TObject; const ACOMhandle : THandle; var AConfig : TCommConfig; var ATimeouts : TCommTimeouts);
begin
  if (FBaudRate > 0) then
    AConfig.dcb.BaudRate := FBaudRate;
end;

end.
