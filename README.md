unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, dbf, db, FileUtil, Forms, Controls, Graphics, Dialogs,
  DBGrids, StdCtrls, DbCtrls;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button2: TButton;
    CheckBox1: TCheckBox;
    DataSource1: TDataSource;
    Dbf1: TDbf;
    DBGrid1: TDBGrid;
    DBNavigator1: TDBNavigator;
    Edit1: TEdit;
    Label1: TLabel;
    Label3: TLabel;
    OpenDialog1: TOpenDialog;
    procedure Button2Click(Sender: TObject);
    procedure CheckBox1Change(Sender: TObject);
    procedure FormResize(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }



procedure TForm1.Button2Click(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    edit1.text:=ExtractFileDir(OpenDialog1.FileName);
    Label3.Caption:=ExtractFileName(OpenDialog1.FileName);
    if ((ExtractFileExt(Label3.Caption))<>'.dbf')and((ExtractFileExt(Label3.Caption))<>'.DBF') then
    begin
      ShowMessage('Beklenmeyen dosya biçimi.');
      exit;
    end;
  end;
  dbf1.Active:=false;
  dbf1.FilePath:=Edit1.Text;
  dbf1.TableName:=Label3.Caption;
  dbf1.Active:=true;
end;

procedure TForm1.CheckBox1Change(Sender: TObject);
begin
  if CheckBox1.Checked=True then
  begin
     DBGrid1.ReadOnly:=True;
     DBNavigator1.Enabled:=false;
  end
  else
  begin
    DBGrid1.ReadOnly:=false;
    DBNavigator1.Enabled:=true;
  end;
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  DBGrid1.Height:=Form1.Height-100;
  DBGrid1.Width:=Form1.Width-30;
end;

end.


