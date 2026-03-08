unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  ExtCtrls, Unix, BaseUnix, process, FileUtil, StrUtils;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button10: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Button7: TButton;
    Button8: TButton;
    Button9: TButton;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    MemoBetikler: TMemo;
    Memo2: TMemo;
    Memo3: TMemo;
    Memo4: TMemo;
    Memo5: TMemo;
    OpenDialog1: TOpenDialog;
    PageControl1: TPageControl;
    Panel1: TPanel;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    TabSheet4: TTabSheet;
    procedure Button10Click(Sender: TObject);
    procedure Button11Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure Button9Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Memo3Change(Sender: TObject);
    procedure Memo5Change(Sender: TObject);
    procedure MemoBetiklerChange(Sender: TObject);
  private
    PisiDepo: TStringList; // Tüm pisi paketlerini burada tutacağız
    function ZstToXzDonustur(const CalismaDizini: string): Boolean;
    function RunCommandAndGetOutput(Command: string): string;
    function DebianToPisi(DebName: string): string;
    function ReadFileToString(FilePath: string): string;

  public

  end;

var
  Form1: TForm1;
  K:LongInt;
  AppPath,DebDosyasi,Komut,Cikti: string;
  HamListe, TemizListe, Paket: string;
  Parcalar: TStringArray;
  i: Integer;
  Paketler: TStringArray;
  PisiPaket, SonucXML: string;
  Liste: TStringList;
  PaketAdi: string;
  AProcess: TProcess;
  Baslik: string;
  DebPath, AyiklamaKlasoru: string;
  FullXML, ActionsFile: TStringList;
  HedefKlasor: string;
implementation

{$R *.lfm}

{ TForm1 }
function TForm1.ZstToXzDonustur(const CalismaDizini: string): Boolean;
var
  ZstDosyasi, XzDosyasi, GeciciKlasor: string;
begin
  Result := False;
  ZstDosyasi := CalismaDizini + '/data.tar.zst';
  XzDosyasi := CalismaDizini + '/data.tar.xz';
  GeciciKlasor := CalismaDizini + '/gecici_ayiklama';

  // 1. Kontrol: Ortada bir zst dosyası var mı?
  if not FileExists(ZstDosyasi) then
  begin
    // Eğer dosya zaten xz ise (bazı deb paketleri gibi), işleme gerek yok
    if FileExists(XzDosyasi) then Exit(True);
    Memo4.Lines.Add('Hata: Dönüştürülecek .zst dosyası bulunamadı!');
    Exit(False);
  end;

  try
    Memo4.Lines.Add('Dönüştürme işlemi başlıyor (zst -> xz)...');

    // 2. Temizlik: Eski kalıntıları temizle ve klasör oluştur
    fpSystem(PChar('rm -rf ' + GeciciKlasor));
    fpSystem(PChar('mkdir -p ' + GeciciKlasor));

    // 3. Ayıklama: .zst içeriğini geçici klasöre aç
    Memo4.Lines.Add('Adım 1: zst içeriği dışarı aktarılıyor...'); Application.ProcessMessages; // Arayüzü tazele!
    if fpSystem(PChar('tar --zstd -xf ' + ZstDosyasi + ' -C ' + GeciciKlasor)) <> 0 then
    begin
      Memo4.Lines.Add('Hata: zst ayıklanamadı! Sistemde "zstd" kurulu mu?');
      Exit(False);
    end;

    // 4. Yeniden Paketleme: İçeriği XZ (J parametresi) olarak paketle
    Memo4.Lines.Add('Adım 2: xz formatında sıkıştırılıyor (Bu biraz sürebilir)...'); Application.ProcessMessages; // Arayüzü tazele!
    // Not: 'cd' komutuyla klasöre girip paketlemek, dosya yollarının doğru olması için kritiktir.
    if fpSystem(PChar('cd ' + GeciciKlasor + ' && tar -cJf ' + XzDosyasi + ' .')) <> 0 then
    begin
      Memo4.Lines.Add('Hata: XZ paketleme başarısız!'); Application.ProcessMessages; // Arayüzü tazele!
      Exit(False);
    end;

    // 5. Final: Geçici dosyaları temizle ve zst'yi sil (opsiyonel)
    fpSystem(PChar('rm -rf ' + GeciciKlasor));
     fpSystem(PChar('rm -f ' + ZstDosyasi)); // İstersen orijinal zst'yi silebilirsin

    Memo4.Lines.Add('Başarılı: data.tar.xz oluşturuldu.');Application.ProcessMessages; // Arayüzü tazele!
    Result := True;
  except
    on E: Exception do
    begin
      Memo4.Lines.Add('Dönüştürme sırasında beklenmedik hata: ' + E.Message);
      Application.ProcessMessages;
    end;
  end;
end;

function TForm1.RunCommandAndGetOutput(Command: string): string;
var
  S: string;
begin
  Result := '';
  // Komutu çalıştır ve sonucunu geçici bir dosyaya at, sonra oku
  if RunCommand('/bin/sh', ['-c', Command], S) then
    Result := S;
end;

function TForm1.ReadFileToString(FilePath: string): string;
var
  SL: TStringList;
begin
  Result := '';
  if FileExists(FilePath) then
  begin
    SL := TStringList.Create;
    try
      SL.LoadFromFile(FilePath);
      Result := SL.Text;
    finally
      SL.Free;
    end;
  end;
end;

function TForm1.DebianToPisi(DebName: string): string;
var
  TemizAd, TahminAd: string;
  P: Integer;
begin
  // --- 1. ADIM: PARANTEZ VE VERSİYON TEMİZLİĞİ ---
  TemizAd := Trim(DebName);
  P := Pos('(', TemizAd);
  if P > 0 then
    TemizAd := Trim(Copy(TemizAd, 1, P - 1));

  TemizAd := LowerCase(TemizAd);

  // --- 2. ADIM: MANUEL EŞLEŞTİRME (Sözlük) ---
  case TemizAd of
    // Sistem ve Temel Kütüphaneler
    'libc6':             Exit('glibc');
    'libgcc-s1':         Exit('libgcc');
    'libstdc++6':        Exit('libstdc++');
    'zlib1g':            Exit('zlib');
    'zlib1g-dev':        Exit('zlib-devel');
    'libbz2-1.0':        Exit('bzip2-libs');
    'liblzma5':          Exit('xz-libs');
    'libzstd1':          Exit('zstd');

    // Grafik ve Font (Büyük-Küçük Harf Hassasiyeti Önemli)
    'libx11-6':          Exit('libX11');
    'libxext6':          Exit('libXext');
    'libxft2':           Exit('libXft');
    'libxmu6':           Exit('libXmu');
    'libxt6':            Exit('libXt');
    'libpng16-16':       Exit('libpng');
    'libjpeg62-turbo':   Exit('jpeg-turbo');
    'libfontconfig1':    Exit('fontconfig');
    'libgl1-mesa-glx':   Exit('mesa');

    // Network ve Güvenlik
    'libssl3', 'libssl1.1', 'libssl1.0.0': Exit('openssl');
    'libcurl4':          Exit('curl');
    'libdbus-1-3':       Exit('dbus-libs');
    'libssh2-1':         Exit('libssh2');
    'libpcap0.8':        Exit('libpcap');
    'libpcre3':          Exit('pcre');
    'liblinear4':        Exit('liblinear');
    'libsqlite3-0':      Exit('sqlite');
    'libsqlite3-dev':    Exit('sqlite-devel');

    // Ses ve Diller
    'libasound2':        Exit('alsa-lib');
    'libasound2-dev':    Exit('alsa-lib-devel');
    'libpulse0':         Exit('pulseaudio-libs');
    'python3-tk':        Exit('python3-tk');
    'liblua5.3-0',
    'liblua5.4-0':       Exit('lua');
    'lua-lpeg':          Exit('lua-lpeg');
    'nmap-common':       Exit('nmap');
  end;

  // --- 3. ADIM: OTOMATİK KURALLAR (-dev -> -devel) ---
  TahminAd := TemizAd;
  if EndsText('-dev', TahminAd) then
    TahminAd := Copy(TahminAd, 1, Length(TahminAd) - 4) + '-devel';

  // --- 4. ADIM: PİSİ DEPOSUNDA DOĞRULAMA ---
  // Eğer tahmin ettiğimiz isim (zstd-devel gibi) pisi_liste.txt içinde varsa onu kullan
  if (PisiDepo <> nil) and (PisiDepo.IndexOf(TahminAd) <> -1) then
    Result := TahminAd
  else
    Result := TemizAd; // Manuel eşleşme yoksa ve depoda bulunamazsa temiz adı döndür
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  EksikPaketler: string;

  function KomutVarMi(Komut: string): Boolean;
  begin
    // which komutu ile sistemde arama yapıyoruz
    Result := fpSystem('which ' + Komut + ' > /dev/null 2>&1') = 0;
  end;
begin

  if BaseUnix.fpgetuid <> 0 then
  begin
       if FileExists('/usr/bin/pkexec') then
       K := fpSystem('pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY ' + Application.ExeName)
       else if FileExists('/usr/bin/kdesu') then
       K := fpSystem('kdesu ' + Application.ExeName)
       else
       ShowMessage('Hata: Yetki yönetici (pkexec veya kdesu) bulunamadı! Lütfen uygulamayı terminalden "sudo" ile çalıştırın.');
       halt; // Yetkisiz oturumu kapat
  end;
  //Paket isimlerini indir.
  PisiDepo := TStringList.Create;
  PisiDepo.Sorted := True; // Arama hızı için sıralı olması şart
  if FileExists('pisi_liste.txt') then
  PisiDepo.LoadFromFile('pisi_liste.txt');

  EksikPaketler := '';

  // --- KRİTİK BAĞIMLILIK KONTROLÜ ---
  if not KomutVarMi('ar') then EksikPaketler := EksikPaketler + ' - binutils (ar)' + sLineBreak;
  if not KomutVarMi('sha1sum') then EksikPaketler := EksikPaketler + ' - coreutils (sha1sum)' + sLineBreak;
  if not KomutVarMi('pisi') then EksikPaketler := EksikPaketler + ' - pisi' + sLineBreak;
  if not KomutVarMi('tar') then EksikPaketler := EksikPaketler + ' - tar' + sLineBreak;
  if not KomutVarMi('xz') then EksikPaketler := EksikPaketler + ' - xz' + sLineBreak;

  if EksikPaketler <> '' then
  begin
    ShowMessage('Dikkat! Programın çalışması için gerekli bazı paketler eksik:' + sLineBreak +
                EksikPaketler + sLineBreak +
                'Lütfen bu paketleri Pisi depolarından kurun.');
    Memo4.Lines.Add('[!] SİSTEM UYARISI: Eksik bağımlılıklar tespit edildi!');
  end
  else
  begin
    Memo4.Lines.Add('[+] Sistem kontrolü başarılı: Tüm bağımlılıklar kurulu.');
  end;

  // Formun geri kalan başlangıç işlemleri...
  Memo4.Lines.Add('Deb2Pisi (Mecazi Edition) Başlatıldı.');
end;

procedure TForm1.Memo3Change(Sender: TObject);
begin
  Memo3.Lines.SaveToFile('/root/pisilik/pspec.xml');
end;

procedure TForm1.Memo5Change(Sender: TObject);
begin
  Memo5.Lines.SaveToFile('/root/pisilik/actions.py');
end;

procedure TForm1.MemoBetiklerChange(Sender: TObject);
begin
  MemoBetikler.Lines.SaveToFile('/root/pisilik/package.py');
end;


procedure TForm1.Button1Click(Sender: TObject);
var
  i: Integer;
  HamListe, TemizListe, Paket, Cikti, Komut: string;
  Parcalar: TStringArray;
begin
  if OpenDialog1.Execute then
  begin
    DebDosyasi := OpenDialog1.FileName;
    Memo4.Clear; // Log ekranını temizle
    Memo4.Lines.Add('Seçilen Paket: ' + ExtractFileName(DebDosyasi));
    Application.ProcessMessages;
    // --- 1. ÇALIŞMA DİZİNİNİ HAZIRLA ---
    fpSystem('rm -rf /root/pisilik');
    fpSystem('mkdir -p /root/pisilik');

    Komut := 'cp ' + QuotedStr(DebDosyasi) + ' /root/pisilik/paket.deb';
    fpSystem(PChar(Komut));

    // --- 2. PAKETİ PARÇALA ---
    Memo4.Lines.Add('Paket parçalanıyor (ar x)...'); Application.ProcessMessages; // Arayüzü tazele!
    fpSystem('cd /root/pisilik && ar x paket.deb');

    // --- 3. CONTROL VE CONFFILES DOSYALARINI AYIKLA VE OKU ---
    if FileExists('/root/pisilik/control.tar.zst') then
      fpSystem('tar --zstd -xf /root/pisilik/control.tar.zst -C /root/pisilik/ ./control ./conffiles 2>/dev/null')
    else if FileExists('/root/pisilik/control.tar.xz') then
      fpSystem('tar -xf /root/pisilik/control.tar.xz -C /root/pisilik/ ./control ./conffiles 2>/dev/null')
    else if FileExists('/root/pisilik/control.tar.gz') then
      fpSystem('tar -xf /root/pisilik/control.tar.gz -C /root/pisilik/ ./control ./conffiles 2>/dev/null');

    // Hata ayıklama için log düşelim
    if FileExists('/root/pisilik/conffiles') then
       begin
       Memo4.Lines.Add('Yapılandırma listesi (conffiles) bulundu.');
       Application.ProcessMessages; // Arayüzü tazele!
       end
    else
       Memo4.Lines.Add('Paket yapılandırma dosyası içermiyor (conffiles yok).');
       Application.ProcessMessages; // Arayüzü tazele!

    if FileExists('/root/pisilik/control') then
    begin
       if RunCommand('bash', ['-c', 'grep "^Depends:" /root/pisilik/control | cut -d":" -f2'], Cikti) then
       begin
         HamListe := Trim(Cikti);
         Edit1.Text := HamListe;

         TemizListe := '';
         Parcalar := HamListe.Split([',', '|']);

         for i := 0 to High(Parcalar) do
         begin
           Paket := Trim(Parcalar[i]);
           if Pos(' ', Paket) > 0 then Paket := Copy(Paket, 1, Pos(' ', Paket) - 1);
           if Pos('(', Paket) > 0 then Paket := Copy(Paket, 1, Pos('(', Paket) - 1);

           Paket := Trim(Paket);
           if Paket <> '' then
             TemizListe := TemizListe + Paket + ' ';
         end;

         Edit2.Text := Trim(TemizListe);
         Button9Click(self); //pisi bağımlılıklarına dönüştür.
         Memo4.Lines.Add('Bağımlılıklar Başarıyla Okundu: ' + Edit2.Text);
         Application.ProcessMessages; // Arayüzü tazele!
       end;
    end
    else
      Memo4.Lines.Add('Uyarı: Bağımlılık listesi (control) okunamadı.');
      Application.ProcessMessages; // Arayüzü tazele!

    // --- 4. ZST -> XZ DÖNÜŞTÜRME FONKSİYONUNU ÇAĞIR ---
    if ZstToXzDonustur('/root/pisilik') then
    begin
      Memo4.Lines.Add('Dönüştürme başarılı veya zaten xz formatında.'); Application.ProcessMessages; // Arayüzü tazele!
      Memo4.Lines.Add('Artık (pspec oluştur) düğmesine basabilirsin.'); Application.ProcessMessages; // Arayüzü tazele!
    end
    else
    begin
      Memo4.Lines.Add('Hata: Data dosyası dönüştürülemedi! İnşa süreci riskli.');Application.ProcessMessages; // Arayüzü tazele!
    end;
  end;
end;



procedure TForm1.Button11Click(Sender: TObject);
var
  ConfList: TStringList;
  AnaDizin, HedefFiles, Satir, KaynakDosya, KomutCiktisi: string;
  i, Sayac: Integer;
begin
  Sayac := 0;
  HedefFiles := '/root/pisilik/files/';
  ForceDirectories(HedefFiles);

  // 1. ADIM: /var/pisi altındaki klasörü bul (Körü körüne Edit1'e güvenme)
  // En son işlem yapılan klasörü bulmak için 'ls -td' kullanıyoruz (tarihe göre sırala)
  if RunCommand('/bin/sh', ['-c', 'ls -td /var/pisi/*/ | head -n 1'], KomutCiktisi) then
    AnaDizin := Trim(KomutCiktisi) + 'install'
  else
    AnaDizin := '';

  // Manuel Kontrol: Eğer yukarıdaki boş dönerse Edit1'den dene
  if (AnaDizin = 'install') or (AnaDizin = '') then
     AnaDizin := '/var/pisi/' + Trim(Edit1.Text) + '-3-1/install';

  if not DirectoryExists(AnaDizin) then
  begin
    Memo4.Lines.Add('HATA: Klasör bulunamadı! Yol: ' + AnaDizin);
    Memo4.Lines.Add('Lütfen terminalde "ls /var/pisi" yazıp klasör adını kontrol et.');
    Exit;
  end;

  Memo4.Lines.Add('Çalışılan Gerçek Yol: ' + AnaDizin);

  // 2. ADIM: Kopyalama İşlemi
  if FileExists('/root/pisilik/conffiles') then
  begin
    ConfList := TStringList.Create;
    try
      ConfList.LoadFromFile('/root/pisilik/conffiles');
      for i := 0 to ConfList.Count - 1 do
      begin
        Satir := Trim(ConfList[i]);
        if (Satir = '') or (Satir.StartsWith('#')) then Continue;

        if Satir[1] <> '/' then Satir := '/' + Satir;
        KaynakDosya := AnaDizin + Satir;

        if FileExists(KaynakDosya) then
        begin
          if CopyFile(KaynakDosya, HedefFiles + ExtractFileName(Satir)) then
          begin
            Memo4.Lines.Add('TAMAM: ' + ExtractFileName(Satir));
            Inc(Sayac);
          end;
        end;
      end;

      // Özel durum: mc.keymap'i de alalım
      if FileExists(AnaDizin + '/etc/mc/mc.keymap') then
         CopyFile(AnaDizin + '/etc/mc/mc.keymap', HedefFiles + 'mc.keymap');

    finally
      ConfList.Free;
    end;
  end;
  ShowMessage(IntToStr(Sayac) + ' dosya files/ klasörüne kopyalandı.');
end;

procedure TForm1.Button10Click(Sender: TObject);
begin
  // Sadece geçici dosyaları siliyoruz, pisi paketini ve kaynak deb'i koruyabilirsin
  fpSystem('rm -rf /root/pisilik/files');
  fpSystem('rm -f /root/pisilik/control /root/pisilik/conffiles /root/pisilik/data.tar*');
  fpSystem('rm -f /root/pisilik/package.py /root/pisilik/actions.py /root/pisilik/pspec.xml');
  Memo4.Lines.Clear;
  Memo4.Lines.Add('Geçici dosyalar temizlendi. Saha yeni paket için hazır!');
end;


procedure TForm1.Button2Click(Sender: TObject);
var
  S, Kelime, SonucXML: string;
  i, k: Integer;
  ConfList: TStringList;
  ConfDosyaYolu, Satir: string;
begin
  Memo2.Lines.Clear;

  // ARTIK KAYNAĞIMIZ EDIT3 (Pisi Karşılıkları)
  S := Trim(Edit3.Text);

  if S = '' then
  begin
    Exit;
  end;

  // --- 1. RUNTIME (BAĞIMLILIKLAR) KISMI ---
  SonucXML := '<Runtime>' + sLineBreak;
  Kelime := '';
  S := S + ' '; // Son kelimeyi yakalamak için

  for i := 1 to Length(S) do
  begin
    if S[i] <> ' ' then
      Kelime := Kelime + S[i]
    else
    begin
      if Kelime <> '' then
      begin
        // Mükerrer kontrolü
        if Pos('<Dependency>' + Kelime + '</Dependency>', SonucXML) = 0 then
          SonucXML := SonucXML + '    <Dependency>' + Kelime + '</Dependency>' + sLineBreak;

        Kelime := '';
      end;
    end;
  end;
  SonucXML := SonucXML + '</Runtime>' + sLineBreak;

  // --- 2. CONFFILES (ADDITIONAL FILES) KISMI ---
  ConfDosyaYolu := '/root/pisilik/conffiles';
  if FileExists(ConfDosyaYolu) then
  begin
    ConfList := TStringList.Create;
    try
      ConfList.LoadFromFile(ConfDosyaYolu);

      SonucXML := SonucXML + '    <AdditionalFiles>' + sLineBreak;

      for k := 0 to ConfList.Count - 1 do
      begin
        Satir := Trim(ConfList[k]);
        if Satir <> '' then
        begin
             if Trim(Satir) <> '' then
             begin
              SonucXML := SonucXML + '        <AdditionalFile target="' + Trim(Satir) + '">' +
              ExtractFileName(Trim(Satir)) + '</AdditionalFile>' + sLineBreak;
             end;
        end;
      end;

      SonucXML := SonucXML + '    </AdditionalFiles>' + sLineBreak;
    finally
      ConfList.Free;
    end;
  end;

  // Sonuçların tamamını Memo2'ye tek seferde basıyoruz
  Memo2.Lines.Text := SonucXML;
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  SHA1Sonuc, PaketAdiTemiz, ArsivDosyasi, ArsivTipi, Komut, PaketVersiyon, Satir: string;
  FullXML, ConfList, MemoSatirlari: TStringList;
  i: Integer;
  DosyaAdi: string;
begin
  // --- 1. ADIM: DOSYA TESPİTİ ---
  ArsivDosyasi := 'data.tar.xz';
  ArsivTipi := 'tarxz';

  if not FileExists('/root/pisilik/' + ArsivDosyasi) then
  begin
    Memo4.Lines.Add('Hata: data.tar.xz bulunamadı!');
    Exit;
  end;

  // --- 2. ADIM: SHA1 HESAPLAMA ---
  Komut := 'sha1sum "/root/pisilik/' + ArsivDosyasi + '" | awk ''{print $1}''';
  if not RunCommand('bash', ['-c', Komut], SHA1Sonuc) then
  begin
    Memo4.Lines.Add('Hata: SHA1 hesaplanamadı!');
    Exit;
  end;
  SHA1Sonuc := Trim(SHA1Sonuc);

  // --- 3. ADIM: VERSİYON TEMİZLEME ---
  PaketVersiyon := '1.0.0';
  if FileExists('/root/pisilik/control') then
  begin
    if RunCommand('bash', ['-c', 'grep "^Version:" /root/pisilik/control | cut -d":" -f2'], PaketVersiyon) then
    begin
      PaketVersiyon := Trim(PaketVersiyon);
      if Pos(':', PaketVersiyon) > 0 then PaketVersiyon := Copy(PaketVersiyon, Pos(':', PaketVersiyon) + 1, Length(PaketVersiyon));
      if Pos('-', PaketVersiyon) > 0 then PaketVersiyon := Copy(PaketVersiyon, 1, Pos('-', PaketVersiyon) - 1);
      if Pos('+', PaketVersiyon) > 0 then PaketVersiyon := Copy(PaketVersiyon, 1, Pos('+', PaketVersiyon) - 1);
      if Pos('~', PaketVersiyon) > 0 then PaketVersiyon := Copy(PaketVersiyon, 1, Pos('~', PaketVersiyon) - 1);
      PaketVersiyon := Trim(PaketVersiyon);
    end;
  end;

  // --- 4. ADIM: PAKET ADI ---
  PaketAdiTemiz := LowerCase(StringReplace(ExtractFileName(DebDosyasi), '_', '-', [rfReplaceAll]));
  if Pos('-', PaketAdiTemiz) > 0 then
    PaketAdiTemiz := Copy(PaketAdiTemiz, 1, Pos('-', PaketAdiTemiz) - 1)
  else
    PaketAdiTemiz := ChangeFileExt(PaketAdiTemiz, '');

  // --- 5. ADIM: PSPEC.XML OLUŞTURMA ---
  FullXML := TStringList.Create;
  try
    FullXML.Add('<?xml version="1.0" encoding="utf-8" ?>');
    FullXML.Add('<!DOCTYPE PISI SYSTEM "http://www.pisilinux.org/projeler/pisi/pisi-spec.dtd">');
    FullXML.Add('<PISI>');
    FullXML.Add('    <Source>');
    FullXML.Add('        <Name>' + PaketAdiTemiz + '</Name>');
    FullXML.Add('        <Homepage>https://www.pisilinux.org</Homepage>');
    FullXML.Add('        <Packager><Name>Mecazi</Name><Email>mecazi@pisilinux.org</Email></Packager>');
    FullXML.Add('        <License>GPLv2</License>');
    FullXML.Add('        <Summary xml:lang="tr">' + PaketAdiTemiz + ' paketi</Summary>');
    FullXML.Add('        <Description xml:lang="tr">Deb2Pisi ile otomatik dönüştürülmüştür.</Description>');
    FullXML.Add('        <Archive sha1sum="' + SHA1Sonuc + '" type="' + ArsivTipi + '">file:///root/pisilik/' + ArsivDosyasi + '</Archive>');
    FullXML.Add('    </Source>');

    FullXML.Add('    <Package>');
    FullXML.Add('        <Name>' + PaketAdiTemiz + '</Name>');
    FullXML.Add('        <Summary xml:lang="tr">' + PaketAdiTemiz + ' paketi</Summary>');
    FullXML.Add('        <Description xml:lang="tr">Otomatik dönüştürülmüştür.</Description>');

    // --- 6. ADIM: AKILLI MEMO2 FİLTRELEME ---
    if Trim(Memo2.Lines.Text) <> '' then
    begin
      MemoSatirlari := TStringList.Create;
      try
        MemoSatirlari.Text := Memo2.Lines.Text;
        for i := 0 to MemoSatirlari.Count - 1 do
        begin
          Satir := Trim(MemoSatirlari[i]);
          if (Satir = '') or (Satir = '<AdditionalFiles>') or (Satir = '</AdditionalFiles>') then Continue;

          if Pos('<AdditionalFile', Satir) > 0 then
          begin
            DosyaAdi := Copy(Satir, Pos('>', Satir) + 1, Length(Satir));
            DosyaAdi := Copy(DosyaAdi, 1, Pos('</', DosyaAdi) - 1);

            if FileExists('/root/pisilik/files/' + DosyaAdi) then
            begin
              if Pos('<AdditionalFiles>', FullXML.Text) = 0 then
                FullXML.Add('    <AdditionalFiles>');
              FullXML.Add('        ' + Satir);
            end
            else
              Memo4.Lines.Add('[-] XML Filtresi: Dosya yok, atlandı: ' + DosyaAdi);
          end
          else
            FullXML.Add('    ' + Satir);
        end;

        if Pos('<AdditionalFiles>', FullXML.Text) > 0 then
          FullXML.Add('    </AdditionalFiles>');
      finally
        MemoSatirlari.Free;
      end;
    end;

    // --- 7. ADIM: FILES BLOĞU VE KÜTÜPHANE DESTEĞİ ---
    FullXML.Add('        <Files>');
    if FileExists('/root/pisilik/conffiles') then
    begin
      ConfList := TStringList.Create;
      try
        ConfList.LoadFromFile('/root/pisilik/conffiles');
        for i := 0 to ConfList.Count - 1 do
        begin
          if Trim(ConfList[i]) <> '' then
          begin
            if FileExists('/root/pisilik/files/' + ExtractFileName(Trim(ConfList[i]))) then
               FullXML.Add('            <Path fileType="config">' + Trim(ConfList[i]) + '</Path>')
            else
               Memo4.Lines.Add('[-] XML Filtresi (Conffiles): Dosya diskte yok, çıkarıldı: ' + ExtractFileName(Trim(ConfList[i])));
          end;
        end;
      finally
        ConfList.Free;
      end;
    end;

    // Standart Dizinler ve Gelişmiş Yol Tanımları
    FullXML.Add('            <Path fileType="executable">/usr/bin/*</Path>');
    FullXML.Add('            <Path fileType="executable">/bin/*</Path>');
    // Kütüphane dosyaları için derinlik artırıldı (x86_64-linux-gnu vb. için)
    FullXML.Add('            <Path fileType="library">/usr/lib/*</Path>');
    FullXML.Add('            <Path fileType="library">/usr/lib/*/*</Path>');
    FullXML.Add('            <Path fileType="library">/lib/*</Path>');
    FullXML.Add('            <Path fileType="library">/lib/*/*</Path>');
    // Header dosyaları için destek eklendi (zlib gibi paketler için kritik)
    FullXML.Add('            <Path fileType="header">/usr/include/*</Path>');
    FullXML.Add('            <Path fileType="data">/usr/share/*</Path>');
    FullXML.Add('            <Path fileType="config">/etc/*</Path>');
    FullXML.Add('            <Path fileType="doc">/usr/share/doc/*</Path>');
    FullXML.Add('        </Files>');

    FullXML.Add('    </Package>');

    // --- 8. ADIM: GEÇMİŞ (HISTORY) ---
    FullXML.Add('    <History><Update release="1">');
    FullXML.Add('        <Date>' + FormatDateTime('yyyy-mm-dd', Now) + '</Date>');
    FullXML.Add('        <Version>' + PaketVersiyon + '</Version>');
    FullXML.Add('        <Comment>Paket çevrimi yapıldı.</Comment>');
    FullXML.Add('        <Name>Mecazi</Name><Email>m@m.org</Email>');
    FullXML.Add('    </Update></History>');
    FullXML.Add('</PISI>');

    FullXML.SaveToFile('/root/pisilik/pspec.xml');
    Memo3.Lines.Text := FullXML.Text;
    Memo4.Lines.Add('[+] pspec.xml başarıyla oluşturuldu. Versiyon: ' + PaketVersiyon);
    Application.ProcessMessages;

  finally
    FullXML.Free;
  end;
end;

procedure TForm1.Button4Click(Sender: TObject);
var
  AProcess: TProcess;
  Buffer: array[1..2048] of Byte;
  ReadCount: LongInt;
  StrOutput,S: string;
begin
  // Klasör kontrolü
  if not DirectoryExists('/root/pisilik/') then
  begin
    Memo4.Lines.Add('Çalışma dizini bulunamadı!'); Application.ProcessMessages; // Arayüzü tazele!
    Exit;
  end;

  AProcess := TProcess.Create(nil);
  try
    // Bash üzerinden komutu çalıştırıyoruz
    AProcess.Executable := '/bin/bash';
    AProcess.Parameters.Add('-c');
    AProcess.Parameters.Add('cd /root/pisilik/ && pisi build pspec.xml --no-color');

    // Pipe ayarları
    AProcess.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
    AProcess.Execute;

    // Süreç çalıştığı sürece ÇIKTIYI OKU
    while AProcess.Running or (AProcess.Output.NumBytesAvailable > 0) do
    begin
      if AProcess.Output.NumBytesAvailable > 0 then
      begin
        // Buffer taşmasını önlemek için uygun boyutta oku
        ReadCount := AProcess.Output.Read(Buffer, SizeOf(Buffer));
        if ReadCount > 0 then
        begin
          SetLength(StrOutput, ReadCount);
          Move(Buffer, StrOutput[1], ReadCount);
          // Memo'nun sonuna ekle ve kaydır
          Memo4.Lines.BeginUpdate;
          Memo4.SelStart := Length(Memo4.Text);
          Memo4.SelText := StrOutput;
          Memo4.Lines.EndUpdate;
        end;
      end;
      Application.ProcessMessages; // Arayüzün donmasını engeller
      Sleep(10); // İşlemciyi yormamak için kısa bekleme
    end;

  finally
    AProcess.Free; // Belleği temizle
  end;
  Memo4.Lines.Add('İşlem tamamlandı.');

  if RunCommand('bash', ['-c', 'ls -t /root/pisilik/*.pisi | head -n 1'], S) then
  begin
    S := Trim(S);
    if S <> '' then
    begin
      Memo4.Lines.Add('Tebrikler! Paket oluştu: ' + S);
      Application.ProcessMessages;
    end
    else
      Memo4.Lines.Add('Hata: Paket dosyası bulunamadı. Lütfen hata çıktılarını kontrol edin.');
      Application.ProcessMessages; // Arayüzü tazele!
  end;
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  ActionsFile := TStringList.Create;
  try
    ActionsFile.Add('#!/usr/bin/python');
    ActionsFile.Add('# -*- coding: utf-8 -*-');
    ActionsFile.Add('from pisi.actionsapi import pisitools');
    ActionsFile.Add('from pisi.actionsapi import get');
    ActionsFile.Add('from pisi.actionsapi import shelltools');
    ActionsFile.Add('import os');

    ActionsFile.Add('def install():');
    ActionsFile.Add('    xz_path = "/root/pisilik/data.tar.xz"');
    ActionsFile.Add('    if os.path.exists(xz_path):');
    ActionsFile.Add('        shelltools.system("cp %s ." % xz_path)');
    ActionsFile.Add('        shelltools.system("tar -xf data.tar.xz --no-same-owner --no-same-permissions")');
    ActionsFile.Add('    else:');
    ActionsFile.Add('        print("Hata: data.tar.xz bulunamadi!")');

    ActionsFile.Add('    # Ayiklanan klasorleri sisteme yerlestir');
    ActionsFile.Add('    for folder in ["usr", "etc", "opt", "bin", "lib"]:');
    ActionsFile.Add('        if os.path.exists(folder):');
    ActionsFile.Add('            if os.listdir(folder):');
    ActionsFile.Add('                pisitools.insinto("/", folder)');

    ActionsFile.SaveToFile('/root/pisilik/actions.py');
    Memo5.Lines.Text := ActionsFile.Text;
  finally
    ActionsFile.Free;
  end;
  Memo4.Lines.Add('actions.py shelltools desteği ile düzeltildi.');
  Application.ProcessMessages; // Arayüzü tazele!
end;

procedure TForm1.Button6Click(Sender: TObject);
begin

  if FileExists('/usr/bin/dolphin') then
    fpSystem('dolphin /root/pisilik &')
  else if FileExists('/usr/bin/nemo') then
    fpSystem('nemo /root/pisilik &')
  else
    fpSystem('xdg-open /root/pisilik &');
end;

procedure TForm1.Button7Click(Sender: TObject);
var
  EnSonPaket: string;
  AProcess: TProcess;
  Buffer: array[0..2047] of Byte; // Sabit 2048 byte dizi
  BytesRead: LongInt;
  S: string;
//const
 // LocalBufSize = 2048;
begin
  Memo4.Lines.Add('Kurulum işlemi başlatılıyor...');

  // 1. En son üretilen .pisi paketini bul
  if RunCommand('bash', ['-c', 'ls -t /root/pisilik/*.pisi | head -n 1'], EnSonPaket) then
  begin
    EnSonPaket := Trim(EnSonPaket);
    if (EnSonPaket = '') then Exit;

    AProcess := TProcess.Create(nil);
    try
      AProcess.Executable := '/usr/bin/pisi';
      AProcess.Parameters.Add('it');
      AProcess.Parameters.Add('--no-color');
      //AProcess.Parameters.Add('--yes-all');
      AProcess.Parameters.Add(EnSonPaket);

      AProcess.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
      AProcess.Execute;

      // OKUMA DÖNGÜSÜ
      while AProcess.Running or (AProcess.Output.NumBytesAvailable > 0) do
      begin
        if AProcess.Output.NumBytesAvailable > 0 then
        begin
          // Buffer burada array[0..2047] olduğu için sorun çıkmaz
          BytesRead := AProcess.Output.Read(Buffer, SizeOf(Buffer));

          if BytesRead > 0 then
          begin
            SetString(S, PChar(@Buffer[0]), BytesRead);
            Memo4.Lines.Add(S);
            Application.ProcessMessages; // Arayüzü tazele!

            // Memo'yu en aşağı kaydır (Otomatik Scroll)
            Memo4.SelStart := Length(Memo4.Text);
          end;
        end;
        Sleep(10); // Parantez hatası burada düzeldi: Sleep(10);
        Application.ProcessMessages;
      end;

      if AProcess.ExitStatus = 0 then
    begin
      // 1. Teknik detayları loga (Memo) ekle
      Memo4.Lines.Add('---------------------------------------');
      Memo4.Lines.Add('DURUM: Kurulum başarıyla tamamlandı.');
      Memo4.Lines.Add('PAKET: ' + EnSonPaket);
      Memo4.Lines.Add('ZAMAN: ' + DateTimeToStr(Now));
      Application.ProcessMessages; // Arayüzü tazele!

      // 2. Kullanıcıya net bir bitiş mesajı göster
      ShowMessage('Tebrikler!' + #13#10 +
                  EnSonPaket + ' paketi sisteme kuruldu.' + #13#10 +
                  'Artık menüden veya terminalden çalıştırabilirsiniz.');
    end
    else
    begin
      Memo4.Lines.Add('HATA: Pisi kurulumu sırasında bir sorun oluştu.');
      Application.ProcessMessages; // Arayüzü tazele!
      ShowMessage('Eyvah! Kurulum başarısız oldu. Lütfen logları kontrol edin.');
    end;

    finally
      AProcess.Free;
    end;
  end;
end;

procedure TForm1.Button8Click(Sender: TObject);
var
  ControlArsivi, Content, DosyaListesi: string;
  PackageTemplate, ConfList: TStringList;
  i: Integer;

  procedure AddScriptToTemplate(DebFile, PisiFunc: string);
  begin
    PackageTemplate.Add('def ' + PisiFunc + '():');
    if ((PisiFunc = 'postInstall') or (PisiFunc = 'postRemove')) and (Pos('.desktop', DosyaListesi) > 0) then
    begin
      PackageTemplate.Add('    shelltools.system("update-desktop-database -q")');
      PackageTemplate.Add('    shelltools.system("gtk-update-icon-cache -f -t /usr/share/icons/hicolor")');
    end;

    if FileExists('/root/pisilik/' + DebFile) then
    begin
      Content := ReadFileToString('/root/pisilik/' + DebFile);
      PackageTemplate.Add('    # DEBIAN ' + UpperCase(DebFile) + ' YEDEĞİ:');
      PackageTemplate.Add('    # ' + StringReplace(Trim(Content), #10, #10 + '    # ', [rfReplaceAll]));
      Memo4.Lines.Add('[+] ' + DebFile + ' bulundu ve yedeklendi.');
    end
    else
    begin
      if not (((PisiFunc = 'postInstall') or (PisiFunc = 'postRemove')) and (Pos('.desktop', DosyaListesi) > 0)) then
        PackageTemplate.Add('    pass');
    end;
    PackageTemplate.Add('');
  end;

begin
  DosyaListesi := RunCommandAndGetOutput('tar -tf /root/pisilik/data.tar*');
  MemoBetikler.Lines.Clear;
  Memo4.Lines.Add('Paket zekası çalıştırılıyor...');

  PackageTemplate := TStringList.Create;
  try
    // 1. Python Kütüphaneleri (os eklendi)
    PackageTemplate.Add('from pisi.actionsapi import shelltools');
    PackageTemplate.Add('from pisi.actionsapi import pisitools');
    PackageTemplate.Add('from pisi.actionsapi import get');
    PackageTemplate.Add('import os'); // Dosya kontrolü için standart python os modülü
    PackageTemplate.Add('');

    // 2. SETUP
    PackageTemplate.Add('def setup():');
    PackageTemplate.Add('    shelltools.system("tar -xf data.tar.xz")');
    PackageTemplate.Add('');

    // 3. INSTALL
    // --- INSTALL BLOĞUNDA ÖN DENETİM ---
    PackageTemplate.Add('def install():');
    PackageTemplate.Add('    pisitools.insinto("/", "usr")');

    if FileExists('/root/pisilik/conffiles') then
    begin
      ConfList := TStringList.Create;
      try
        ConfList.LoadFromFile('/root/pisilik/conffiles');
        for i := 0 to ConfList.Count - 1 do
        begin
          if Trim(ConfList[i]) <> '' then
          begin
            // BİZ KONTROL EDİYORUZ: package.py'ye sadece var olanları yazıyoruz
            if FileExists('/root/pisilik/files/' + ExtractFileName(Trim(ConfList[i]))) then
            begin
               PackageTemplate.Add(Format('    pisitools.insinto("%s", "files/%s")',
                 [ExtractFilePath(Trim(ConfList[i])), ExtractFileName(Trim(ConfList[i]))]));
            end;
          end;
        end;
      finally
        ConfList.Free;
      end;
    end;
    PackageTemplate.Add('');

    // 4. Betikler
    AddScriptToTemplate('preinst', 'preInstall');
    AddScriptToTemplate('postinst', 'postInstall');
    AddScriptToTemplate('prerm', 'preRemove');
    AddScriptToTemplate('postrm', 'postRemove');

    MemoBetikler.Lines.Text := PackageTemplate.Text;
    MemoBetikler.Lines.SaveToFile('/root/pisilik/package.py');

  finally
    PackageTemplate.Free;
  end;

  Memo4.Lines.Add('package.py (Hata görmezden gelme zekasıyla) hazırlandı.');
  Application.ProcessMessages;
end;

procedure TForm1.Button9Click(Sender: TObject); // Tercüme Et ve Edit3'e Yaz
var
  S, Kelime, PisiPaket, GuncelEdit3: string;
  i: Integer;
begin
  S := Trim(Edit2.Text);
  if S = '' then
  begin
    ShowMessage('Hata: Edit2 (Debian Listesi) boş! Önce bağımlılıkları ayıkla.');
    Exit;
  end;

  GuncelEdit3 := '';
  Kelime := '';
  S := S + ' '; // Son kelimeyi yakalamak için boşluk ekliyoruz

  for i := 1 to Length(S) do
  begin
    if S[i] <> ' ' then
      Kelime := Kelime + S[i]
    else
    begin
      if Kelime <> '' then
      begin
        // TERCÜME BURADA OLUYOR
        // DebianToPisi fonksiyonu libc6'yı glibc yapacak
        PisiPaket := DebianToPisi(Kelime);

        if GuncelEdit3 <> '' then GuncelEdit3 := GuncelEdit3 + ' ';
        GuncelEdit3 := GuncelEdit3 + PisiPaket;

        Kelime := '';
      end;
    end;
  end;

  // Sonucu Edit3'e basıyoruz
  Edit3.Text := GuncelEdit3;

  // LOG ekranına da bilgi düşelim
  Memo4.Lines.Add('Tercüme Tamamlandı: Debian isimleri Pisi karşılıklarına çevrildi.');
end;

end.
