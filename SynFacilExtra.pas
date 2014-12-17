{                               SynFacilRegex
Unidad con rutinas adicionales de SynFacilSyn.
Incluye la definición de "tFaTokContent" y el procesamiento de expresiones regulares
que son usadas por TSynFacilSyn.

                                 Por Tito Hinostroza  02/12/2014 - Lima Perú
}
unit SynFacilExtra;
{$mode objfpc}{$H+}
interface
uses
  SysUtils, Classes, SynEditHighlighter, strutils, Graphics, DOM, LCLIntf,
  SynEditHighlighterFoldBase;

type
  ///////// Definiciones para manejo de tokens por contenido ///////////

  //Tipo de expresión regular soportada. Las exp. regulares soportadas son
  //simples. Solo incluyen literales de cadena o listas.
  tFaRegExpType = (
    tregString,   //Literal de cadena: "casa"
    tregChars,    //Lista de caracteres: [A..Z]
    tregChars01,  //Lista de caracteres: [A..Z]?
    tregChars0_,  //Lista de caracteres: [A..Z]*
    tregChars1_   //Lista de caracteres: [A..Z]+
  );

  tFaActionOnMatch = (
    aomNext,    //pasa a la siguiente instrucción
    aomExit,    //termina la exploración
    aomMovePar, //Se mueve a una posición específica
    aomExitpar  //termina la exploración retomando una posición específica.
  );

  //Estructura para almacenar una instrucción de token por contenido
  tFaTokContentInst = record
    Chars    : array[#0..#255] of ByteBool; //caracteres
    Text     : string;             //cadena válida
    expTyp   : tFaRegExpType;      //tipo de expresión
    TokTyp   : TSynHighlighterAttributes;   //tipo de token al salir
    dMatch   : byte;   //desplazamiento en caso de coincidencia (0 = salir)
    dMiss    : byte;   //desplazamiento en caso de no coincidencia (0 = salir)
    //Campos para ejecutar instrucciones, cuando No cumple
    actionFail : tFaActionOnMatch;
    destOnFail : integer;  //posición destino
    //Campos para ejecutar instrucciones, cuando cumple
    actionMatch: tFaActionOnMatch;
    destOnMatch: integer;  //posición destino

    posFin     : integer;  //para guardar posición
  end;

  ESynFacilSyn = class(Exception);   //excepción del resaltador

  { tFaTokContent }
  //Estructura para almacenar la descripción de los token por contenido
  tFaTokContent = class
    TokTyp    : TSynHighlighterAttributes;   //categoría de token por contenido
//    CharsToken: array[#0..#255] of ByteBool; //caracteres válidos para token por contenido
    //elementos adicionales no usados en esta versión
    Instrucs : array of tFaTokContentInst;  //Instrucciones del token por contenido
    nInstruc : integer;      //Cantidad de instrucciones
    procedure Clear;
//    function ValidateInterval(var cars: string): boolean;
    procedure AddInstruct(exp: string; ifFalse: string='exit';
      TokTyp0: TSynHighlighterAttributes = nil);
    procedure AddRegEx(exp: string);
  private
    function AddItem(expTyp: tFaRegExpType; ifMatch, ifFail: string): integer;
    procedure AddOneInstruct(var exp: string; ifFalse: string='exit';
      TokTyp0: TSynHighlighterAttributes=nil);
  end;

  ///////// Definiciones básicas para el resaltador ///////////

  //Identifica si un token es el delimitador inicial
  TFaTypeDelim =(tdNull,     //no es delimitado
                 tdUniLin,   //es delimitador inicial de token delimitado de una línea
                 tdMulLin,   //es delimitador inicial de token delimitado multilínea
                 tdConten1,  //es delimitador inicial de token por contenido 1
                 tdConten2,  //es delimitador inicial de token por contenido 2
                 tdConten3,  //es delimitador inicial de token por contenido 3
                 tdConten4); //es delimitador inicial de token por contenido 4
  //Tipos de coloreado de bloques
  TFaColBlock = (cbNull,     //sin coloreado
                 cbLevel,    //colorea bloques por nivel
                 cbBlock);   //colorea bloques usando el color definido para cada bloque

  TFaProcMetTable = procedure of object;   //Tipo de procedimiento para procesar el token de
                                         //acuerdo al caracter inicial.
  TFaProcRange = procedure of object;      //Procedimiento para procesar en medio de un rango.

  TFaSynBlock = class;   //definición adelantada

  //Descripción de tokens especiales (identificador o símbolo)
  TTokSpec = record
    txt   : string;        //palabra clave (puede cambiar la caja y no incluir el primer caracter)
    orig  : string;        //palabra clave tal cual se indica
    TokPos: integer;       //posición del token dentro de la línea
    tTok  : TSynHighlighterAttributes;  //tipo de token
    typDel: TFaTypeDelim;  {indica si el token especial actual, es en realidad, el
                            delimitador inicial de un token delimitado o por contenido}
    dEnd  : string;        //delimitador final (en caso de que sea delimitador)
    pRange: TFaProcRange;    //procedimiento para procesar el token o rango(si es multilinea)
    folTok: boolean;       //indica si el token delimitado, tiene plegado
    //propiedades para manejo de bloques y plegado de código
    bloIni : boolean;       //indica si el token es inicio de bloque de plegado
    bloIniL: array of TFaSynBlock;  //lista de referencias a los bloques que abre
    bloFin : boolean;       //indica si el token es fin de bloque de plegado
    bloFinL: array of TFaSynBlock;  //lista de referencias a los bloques que cierra
    secIni : boolean;       //indica si el token es inicio de sección de bloque
    secIniL: array of TFaSynBlock;  //lista de bloques de los que es inicio de sección
    firstSec: TFaSynBlock;     //sección que se debe abrir al abrir el bloque
  end;

  TArrayTokSpec = array of TTokSpec;
  //clase para manejar la definición de bloques de sintaxis
  TFaSynBlock = class
    name        : string;    //nombre del bloque
    index       : integer;   //indica su posición dentro de TFaListBlocks
    showFold    : boolean;   //indica si se mostrará la marca de plegado
    parentBlk   : TFaSynBlock; //bloque padre (donde es válido el bloque)
    BackCol     : TColor;    //color de fondo de un bloque
    IsSection   : boolean;   //indica si es un bloque de tipo sección
    UniqSec     : boolean;   //índica que es sección única
  end;

  TPtrATokEspec = ^TArrayTokSpec;     //puntero a tabla
  TPtrTokEspec = ^TTokSpec;     //puntero a tabla

  //Guarda información sobre un atributo de un nodo XML
  TFaXMLatrib = record  //atributo XML
    hay: boolean;    //bandera de existencia
    val: string;     //valor en cadena
    n  : integer;    //valor numérico
    bol: boolean;    //valor booleando (si aplica)
    col: TColor;     //valor de color (si aplica)
  end;

  { TSynFacilSynBase }
  //Clase con métodos básicos para el resaltador
  TSynFacilSynBase = class(TSynCustomFoldHighlighter)
  protected
    fLine      : PChar;         //Puntero a línea de trabajo
    tamLin     : integer;       //Tamaño de línea actual
    fAtriTable : array[#0..#255] of TSynHighlighterAttributes;   //tabla de atributos de tokens
    fProcTable : array[#0..#255] of TFaProcMetTable;   //tabla de métodos
    posIni     : Integer;       //índice a inicio de token
    posFin     : Integer;       //índice a siguiente token
    fStringLen : Integer;       //Tamaño del token actual
    fToIdent   : PChar;         //Puntero a identificador
    fTokenID   : TSynHighlighterAttributes;  //Id del token actual
    charIni    : char;          //caracter al que apunta fLine[posFin]
    posTok     : integer;       //para identificar el ordinal del token en una línea

    CaseSensitive: boolean;     //Para ignorar mayúscula/minúscula
    charsIniIden: Set of char;  //caracteres iniciales de identificador
    lisTmp     : TStringList;   //lista temporal
  protected   //identificadores especiales
    CharsIdentif: array[#0..#255] of ByteBool; //caracteres válidos para identificadores
    tc1, tc2, tc3, tc4: tFaTokContent;
    //Tablas para identificadores especiales
    mA, mB, mC, mD, mE, mF, mG, mH, mI, mJ,
    mK, mL, mM, mN, mO, mP, mQ, mR, mS, mT,
    mU, mV, mW, mX, mY, mZ:  TArrayTokSpec;  //para mayúsculas
    mA_,mB_,mC_,mD_,mE_,mF_,mG_,mH_,mI_,mJ_,
    mK_,mL_,mM_,mN_,mO_,mP_,mQ_,mR_,mS_,mT_,
    mU_,mV_,mW_,mX_,mY_,mZ_:  TArrayTokSpec;  //para minúsculas
    m_, mDol, mArr, mPer, mAmp, mC3 : TArrayTokSpec;
    mSym        :  TArrayTokSpec;   //tabla de símbolos especiales
    mSym0       :  TArrayTokSpec;   //tabla temporal para símbolos especiales.
    TabMayusc   : array[#0..#255] of Char;     //Tabla para conversiones rápidas a mayúscula
  protected  //funciones básicas
    function BuscTokEspec(var mat: TArrayTokSpec; cad: string; var n: integer;
      TokPos: integer=0): boolean;
    function ToRegExp(interv: string): string;
    procedure VerifDelim(delim: string);
    procedure ValidAsigDelim(delAct, delNue: TFaTypeDelim; delim: string);
    procedure ValidateParamStart(Start: string; var ListElem: TStringList);
    function KeyComp(var r: TTokSpec): Boolean;
    function CreaBuscTokEspec(var mat: TArrayTokSpec; cad: string;
      var i: integer; TokPos: integer=0): boolean;
    //procesamiento de XML
    procedure CheckXMLParams(n: TDOMNode; listAtrib: string);
    function ReadXMLParam(n: TDOMNode; nomb: string): TFaXMLatrib;
  protected
    //Funciones rápidas para la tabla de métodos (tokens por contenido)
    procedure metTokCont(const tc: tFaTokContent); //inline;
    procedure metTokCont1;
    procedure metTokCont2;
    procedure metTokCont3;
    procedure metTokCont4;
  public     //Atributos y sus propiedades de acceso
    //ID para los atributos predefinidos
    tkEol     : TSynHighlighterAttributes;  //id para los tokens salto de línea
    tkSymbol  : TSynHighlighterAttributes;  //id para los símbolos
    tkSpace   : TSynHighlighterAttributes;  //id para los espacios
    tkIdentif : TSynHighlighterAttributes;  //id para los identificadores
    tkNumber  : TSynHighlighterAttributes;  //id para los números
    tkKeyword : TSynHighlighterAttributes;  //id para las palabras claves
    tkString  : TSynHighlighterAttributes;  //id para las cadenas
    tkComment : TSynHighlighterAttributes;  //id para los comentarios
    function NewTokType(TypeName: string): TSynHighlighterAttributes;
    procedure CreateAttributes;  //limpia todos loa atributos
    function GetAttribByName(txt: string): TSynHighlighterAttributes;
    function IsAttributeName(txt: string): boolean;
  end;

function ExtractRegExp(var exp: string; var str: string; var listChars: string): tFaRegExpType;
function ExtractRegExp(var exp: string; var RegexTyp: tFaRegExpType ): string;

implementation
const
    //Mensajes de error generales
//    ERR_START_NO_EMPTY = 'Parámetro "Start" No puede ser nulo';
//    ERR_EXP_MUST_BE_BR = 'Expresión debe ser de tipo [lista de caracteres]';
//    ERR_TOK_DELIM_NULL = 'Delimitador de token no puede ser nulo';
//    ERR_TOK_DEL_IDE_ERR = 'Delimitador de token erróneo: %s (debe ser identificador)';
//    ERR_IDEN_ALREA_DEL = 'Identificador "%s" ya es delimitador inicial.';
//    ERR_INVAL_ATTR_LAB = 'Atributo "%s" no válido para etiqueta <%s>';

    ERR_START_NO_EMPTY = 'Parameter "Start" can not be null';
    ERR_EXP_MUST_BE_BR = 'Expression must be like: [list of chars]';
    ERR_TOK_DELIM_NULL = 'Token delimiter can not be null';
    ERR_TOK_DEL_IDE_ERR = 'Bad Token delimiter: %s (must be identifier)';
    ERR_IDEN_ALREA_DEL = 'Identifier "%s" is already a Start delimiter.';
    ERR_INVAL_ATTR_LAB = 'Invalid attribute "%s" for label <%s>';

    //Mensajes de tokens por contenido
//    ERR_EMPTY_INTERVAL = 'Error: Intervalo vacío.';
//    ERR_DEF_INTERVAL = 'Error en definición de intervalo: %s';
    ERR_EMPTY_INTERVAL = 'Error: Empty Interval.';
    ERR_EMPTY_EXPRES = 'Empty expression.';
    ERR_EXPECTED_BRACK = 'Expected "]".';
    ERR_UNSUPPOR_EXP_ = 'Unsupported expression: ';
    ERR_INC_ESCAPE_SEQ = 'Incomplete Escape sequence';
    ERR_SYN_PAR_IFFAIL_ = 'Syntax error on Parameter "IfFail": ';
    ERR_SYN_PAR_IFMATCH_ = 'Syntax error on Parameter "IfMarch": ';

var
  bajos: string[128];
  altos: string[128];

function copyEx(txt: string; p: integer): string;
//Versión sobrecargada de copy con 2 parámetros
begin
  Result := copy(txt, p, length(txt));
end;
//Funciones para el manejo de expresiones regulares
function ExtractChar(var txt: string; var escaped: boolean; convert: boolean): string;
//Extrae un caracter de una expresión regular. Si el caracter es escapado, devuelve
//TRUE en "escaped"
//Si covert = TRUE, reemplaza el caracter compuesto por uno solo.
var
  c: byte;
begin
  escaped := false;
  Result := '';   //valor por defecto
  if txt = '' then exit;
  if txt[1] = '\' then begin  //caracter escapado
    escaped := true;
    if length(txt) = 1 then  //verificación
      raise ESynFacilSyn.Create(ERR_INC_ESCAPE_SEQ);
    if txt[2] in ['x','X'] then begin
      //caracter en hexadecimal
      if length(txt) < 4 then  //verificación
        raise ESynFacilSyn.Create(ERR_INC_ESCAPE_SEQ);
      if convert then begin    //toma caracter hexdecimal
        c := StrToInt('$'+copy(txt,3,2));
        Result := Chr(c);
      end else begin  //no tranforma
        Result := copy(txt, 1,4);
      end;
      txt := copyEx(txt,5);
    end else begin
      if convert then begin    //toma caracter hexdecimal
        //secuencia normal de dos caracteres
        Result := txt[2];
      end else begin
        Result := copy(txt,1,2);
      end;
      txt := copyEx(txt,3);
    end;
  end else begin   //caracter normal
    Result := txt[1];
    txt := copyEx(txt,2);
  end;
end;
function ExtractChar(var txt: string): char;
//Versión simplificada de ExtractChar(). Extrae un caracter ya convertido. Si no hay
//más caracteres, devuelve #0
var
  escaped: boolean;
  tmp: String;
begin
  if txt = '' then Result := #0
  else begin
    tmp := ExtractChar(txt, escaped, true);
    Result := tmp[1];  //se supone que siempre será de un solo caracter
  end;
end;
function ExtractCharN(var txt: string): string;
//Versión simplificada de ExtractChar(). Extrae un caracter sin convertir.
var
  escaped: boolean;
begin
  Result := ExtractChar(txt, escaped, false);
end;
function ReplaceEscape(str: string): string;
{Reemplaza las secuencias de eescape por su caracter real. Las secuencias de
escape recnocidas son:
* Secuencia de 2 caracteres: "\#", donde # es un caracter cualquiera, excepto"x".
  Esta secuencia equivale al caracter "#".
* Secuencia de 4 caracteres: "\xHH" o "\XHH", donde "HH" es un número hexadecimnal.
  Esta secuencia representa a un caracter ASCII.

Dentro de las expresiones regulares de esta librería, los caracteres: "[", "*", "?",
"*", y "\", tienen significado especial, por eso deben "escaparse".

"\[" -> "["
"\*" -> "*"
"\?" -> "?"
"\+" -> "+"
"\\" -> "\"
}
begin
  Result := '';
  while str<>'' do
    Result += ExtractChar(str);
end;
function PosChar(ch: char; txt: string): integer;
//Similar a Pos(). Devuelve la posición de un caracter que no este "escapado"
var
  f: SizeInt;
begin
  f := Pos(ch,txt);
  if f=1 then exit(1);   //no hay ningún caracter antes.
  while (f>0) and (txt[f-1]='\') do begin
    f := PosEx(ch, txt, f+1);
  end;
  Result := f;
end;
procedure ValidateInterval(var cars: string);
{Valida un conjunto de caracteres, expandiendo los intervalos de tipo "A-Z", y
remplazando las secuencias de escape como: "\[", "\\", "\-", ...
El caracter "-", se considera como indicador de intervalo, a menos que se encuentre
en elprimer o ùltimocaracter de la cadena.
Si hay error genera una excepción.}
var
  c, car1, car2: char;
  car: string;
  tmp: String;
begin
  //reemplaza intervalos
  if cars = '' then
    raise ESynFacilSyn.Create(ERR_EMPTY_INTERVAL);
  car  := ExtractCharN(cars);  //Si el primer caracter es "-". lo toma literal.
  tmp := car;  //inicia cadena para acumular.
  car1 := ExtractChar(car);    //Se asume que es inicio de intervalo. Ademas car<>''. No importa qye se pierda 'car'
  car := ExtractCharN(cars);   //extrae siguiente
  while car<>'' do begin
    if car = '-' then begin
      //es intervalo
      car2 := ExtractChar(cars);   //caracter final
      if car2 = #0 then begin
        //Es intervalo incompleto, podría genera error, pero mejor asumimos que es el caracter "-"
        tmp += '-';
        break;  //sale por que se supone que ya no hay más caracteres
      end;
      //se tiene un intervalo que hay que reemplazar
      for c := Chr(Ord(car1)+1) to car2 do  //No se incluye "car1", porque ya se agregó
        tmp += c;
    end else begin  //simplemente acumula
      tmp += car;
      car1 := ExtractChar(car);    //Se asume que es inicio de intervalo. No importa qye se pierda 'car'
    end;
    car := ExtractCharN(cars);  //extrae siguiente
  end;
  cars := ReplaceEscape(tmp);
  cars := StringReplace(cars, '%HIGH%', altos,[rfReplaceAll]);
  cars := StringReplace(cars, '%ALL%', bajos+altos,[rfReplaceAll]);
end;
function ExtractRegExp(var exp: string; var str: string; var listChars: string): tFaRegExpType;
{Extrae parte de una expresión regular y devuelve el tipo.
En los casos de listas de caracteres, expande los intervalos de tipo: A..Z, reemplaza
las secuencias de escape y devuelve la lista en "listChars".
En el caso de que sea un literal de cadena, reemplaza las secuencias de escape y
devuelve la cadena en "str".
Soporta todas las formas definidas en "tFaRegExpType".
Si encuentra error, genera una excepción.}
var
  f: Integer;
  tmp: string;
  lastAd: String;

begin
  if exp= '' then
    raise ESynFacilSyn.Create(ERR_EMPTY_EXPRES);
  if (exp[1] = '[') and (length(exp)>1) then begin    //Es lista de caracteres
    f := PosChar(']', exp);  //Busca final, obviando "\]"
    if f=0 then
      raise ESynFacilSyn.Create(ERR_EXPECTED_BRACK);
    //El intervalo se cierra
    listChars := copy(exp,2,f-2); //toma interior de lista
    exp := copyEx(exp,f+1);       //extrae parte procesada
    ValidateInterval(listChars);  //puede simplificar "listChars". También puede generar excepción
    if exp = '' then begin   //Lista de tipo "[ ... ]"
      Result := tregChars;
    end else if exp[1] = '*' then begin  //Lista de tipo "[ ... ]* ... "
      exp := copyEx(exp,2);    //extrae parte procesada
      Result := tregChars0_
    end else if exp[1] = '?' then begin  //Lista de tipo "[ ... ]? ... "
      exp := copyEx(exp,2);    //extrae parte procesada
      Result := tregChars01
    end else if exp[1] = '+' then begin  //Lista de tipo "[ ... ]+ ... "
      exp := copyEx(exp,2);    //extrae parte procesada
      Result := tregChars1_
    end else begin
      //No sigue ningún cuantificador, podrías er algún literal
      Result := tregChars;  //Lista de tipo "[ ... ] ... "
    end;
  end else if (length(exp)=1) and (exp[1] in ['*','?','+','[']) then begin
    //Caso especial, no se usa escape, pero no es lista, ni cuantificador. Se asume
    //caracter único
    listChars := exp;  //'['+exp+']'
    exp := '';    //ya no quedan caracteres
    Result := tregChars;
    exit;
  end else begin
    //No inicia con lista. Se puede suponer que inicia con literal cadena.
    {Pueden ser los casos:
      Caso 0) "abc"    (solo literal cadena, se extraerá la cadena "abc")
      Caso 1) "abc[ ... "  (válido, se extraerá la cadena "abc")
      Caso 2) "a\[bc[ ... " (válido, se extraerá la cadena "a[bc")
      Caso 3) "abc* ... "  (válido, pero se debe procesar primero "ab")
      Caso 4) "ab\\+ ... " (válido, pero se debe procesar primero "ab")
      Caso 5) "a? ... "    (válido, pero debe transformarse en lista)
      Caso 6) "\[* ... "   (válido, pero debe transformarse en lista)
    }
    str := '';   //para acumular
    tmp := ExtractCharN(exp);
    lastAd := '';   //solo por seguridad
    while tmp<>'' do begin
      if tmp = '[' then begin
        //Empieza una lista. Caso 1 o 2
        exp:= '[' + exp;  //devuelve el caracter
        str := ReplaceEscape(str);
        if length(str) = 1 then begin  //verifica si tiene un caracter
          listChars := str;       //'['+str+']'
          Result := tregChars;   //devuelve como lista de un caracter
          exit;
        end;
        Result := tregString;   //es literal cadena
        exit;  //sale con lo acumulado en "str"
      end else if (tmp = '*') or (tmp = '?') or (tmp = '+') then begin
        str := copy(str, 1, length(str)-length(lastAd)); //no considera el último caracter
        if str <> '' then begin
          //Hay literal cadena, antes de caracter y cuantificador. Caso 3 o 4
          exp:= lastAd + tmp + exp;  //devuelve el último caracter agregado y el cuantificador
          str := ReplaceEscape(str);
          if length(str) = 1 then begin  //verifica si tiene un caracter
            listChars := str;       //'['+str+']'
            Result := tregChars;   //devuelve como lista de un caracter
            exit;
          end;
          Result := tregString;   //es literal cadena
          exit;
        end else begin
          //Hay caracter y cuantificador. . Caso 5 o 6
          listChars := ReplaceEscape(lastAd);  //'['+lastAd+']'
          //de "exp" ya se quitó: <caracter><cuantificador>
          if          tmp = '*' then begin  //Lista de tipo "[a]* ... "
            Result := tregChars0_
          end else if tmp = '?' then begin  //Lista de tipo "[a]? ... "
            Result := tregChars01
          end else if tmp = '+' then begin  //Lista de tipo "[a]+ ... "
            Result := tregChars1_
          end;   //no hay otra opción
          exit;
        end;
      end;
      str += tmp;   //agrega caracter
      lastAd := tmp;  //guarda el último caracter agregado
      tmp := ExtractCharN(exp);  //siguiente caracter
    end;
    //Si llega aquí es porque no encontró cuantificador ni lista (Caso 0)
    str := ReplaceEscape(str);
    if length(str) = 1 then begin  //verifica si tiene un caracter
      listChars := str;       //'['+str+']'
      Result := tregChars;   //devuelve como lista de un caracter
      exit;
    end;
    Result := tregString;
  end;
end;
function ExtractRegExp(var exp: string; var RegexTyp: tFaRegExpType ): string;
{Extrae parte de una expresión regular y la devuelve como cadena . Actualiza el
tipo de expresión obtenida en "RegexTyp".
No Reemplaza las secuencias de excape ni los intervalos, devuelve el text tal cual}
var
  listChars, str: string;
  exp0: String;
  tam: Integer;
begin
  exp0 := exp;   //guarda expresión tal cual
  RegexTyp := ExtractRegExp(exp, str, listChars);
  tam := length(exp0) - length(exp);  //ve diferencia de tamaño
  Result := copy(exp0, 1, tam)
end;

{ tFaTokContent }
procedure tFaTokContent.Clear;
begin
  nInstruc := 0;
  setLength(Instrucs,0);
end;
function tFaTokContent.AddItem(expTyp: tFaRegExpType; ifMatch, ifFail: string): integer;
//Agrega un ítem a la lista Instrucs[]. Devuelve el número de ítems.
//Configura el comportamiento de la instrucciómn usando "ifMatch".
var
  ifMatch0, ifFail0: string;

  function extractIns(var txt: string): string;
  //Extrae una instrucción (identificador)
  var
    p: Integer;
  begin
    txt := trim(txt);
    if txt = '' then exit('');
    p := 1;
    while (p<=length(txt)) and (txt[p] in ['A'..'Z']) do inc(p);
    Result := copy(txt,1,p-1);
    txt := copyEx(txt, p);
//    Result := copy(txt,1,p);
//    txt := copyEx(txt, p+1);
  end;
  function extractPar(var txt: string; var hasSign: boolean; errMsg: string): integer;
  //Extrae un valor numérico
  var
    p, p0: Integer;
    sign: Integer;
  begin
    txt := trim(txt);
    if txt = '' then exit(0);
    if txt[1] = '(' then begin
      //caso esperado
      hasSign := false;
      p := 2;  //explora
      if not (txt[2] in ['+','-','0'..'9']) then  //validación
        raise ESynFacilSyn.Create(errMsg + ifFail0);
      if txt[2] = '+' then begin
        hasSign := true;
        p := 3;  //siguiente caracter
        sign := 1;
        if not (txt[3] in ['0'..'9']) then
          raise ESynFacilSyn.Create(errMsg + ifFail0);
      end;
      if txt[2] = '-' then begin
        hasSign := true;
        p := 3;  //siguiente caracter
        sign := -1;
        if not (txt[3] in ['0'..'9']) then
          raise ESynFacilSyn.Create(errMsg + ifFail0);
      end;
      //Aquí se sabe que en txt[p], viene un númaro
      p0 := p;   //guarda posición de inicio
      while (p<=length(txt)) and (txt[p] in ['0'..'9']) do inc(p);
      Result := StrToInt(copy(txt,p0,p-p0)) * Sign;  //lee como número
      if txt[p]<>')' then raise ESynFacilSyn.Create(errMsg + ifFail0);
      inc(p);
      txt := copyEx(txt, p+1);
    end else begin
      raise ESynFacilSyn.Create(errMsg + ifFail0);
    end;
  end;
  function HavePar(var txt: string): boolean;
  //Verifica si la cadena empieza con "("
  begin
    Result := false;
    txt := trim(txt);
    if txt = '' then exit;
    if txt[1] = '(' then begin   //caso esperado
      Result := true;
    end;
  end;

var
  inst: String;
  hasSign: boolean;
  n: Integer;
begin
  ifMatch0 := ifMatch;  //guarda valor original
  ifFail0 := ifFail;    //guarda valor original
  inc(nInstruc);
  n := nInstruc-1;  //último índice
  setlength(Instrucs, nInstruc);
  Instrucs[n].expTyp := expTyp;    //tipo
  Instrucs[n].actionMatch := aomNext;  //valor por defecto
  Instrucs[n].actionFail  := aomExit; //valor por defecto
  Instrucs[n].destOnMatch:=0;         //valor por defecto
  Instrucs[n].destOnFail:= 0;         //valor por defecto
  Result := nInstruc;
  //Configura comportamiento
  if ifMatch<>'' then begin
    ifMatch := UpCase(ifMatch);
    while ifMatch<>'' do begin
      inst := extractIns(ifMatch);
      if inst = 'NEXT' then begin  //se pide avanzar al siguiente
        Instrucs[n].actionMatch := aomNext;
      end else if inst = 'EXIT' then begin  //se pide salir
        if HavePar(ifMatch) then begin  //EXIT con parámetro
          Instrucs[n].actionMatch := aomExitpar;
          Instrucs[n].destOnMatch := n + extractPar(ifMatch, hasSign, ERR_SYN_PAR_IFMATCH_);
        end else begin   //EXIT sin parámetros
          Instrucs[n].actionMatch := aomExit;
        end;
      end else if inst = 'MOVE' then begin
        Instrucs[n].actionMatch := aomMovePar;  //Mover a una posición
        Instrucs[n].destOnMatch := n + extractPar(ifMatch, hasSign, ERR_SYN_PAR_IFMATCH_);
      end else begin
        raise ESynFacilSyn.Create(ERR_SYN_PAR_IFMATCH_ + ifMatch0);
      end;
      ifMatch := Trim(ifMatch);
      if (ifMatch<>'') and (ifMatch[1] = ';') then  //quita delimitador
        ifMatch := copyEx(ifMatch,2);
    end;
  end;
  if ifFail<>'' then begin
    ifFail := UpCase(ifFail);
    while ifFail<>'' do begin
      inst := extractIns(ifFail);
      if inst = 'NEXT' then begin  //se pide avanzar al siguiente
        Instrucs[n].actionFail := aomNext;
      end else if inst = 'EXIT' then begin  //se pide salir
        if HavePar(ifFail) then begin  //EXIT con parámetro
          Instrucs[n].actionFail := aomExitpar;
          Instrucs[n].destOnFail := n + extractPar(ifFail, hasSign, ERR_SYN_PAR_IFFAIL_);
        end else begin   //EXIT sin parámetros
          Instrucs[n].actionFail := aomExit;
        end;
      end else if inst = 'MOVE' then begin
        Instrucs[n].actionFail := aomMovePar;  //Mover a una posición
        Instrucs[n].destOnFail := n + extractPar(ifFail, hasSign, ERR_SYN_PAR_IFFAIL_);
      end else begin
        raise ESynFacilSyn.Create(ERR_SYN_PAR_IFFAIL_ + ifFail0);
      end;
      ifFail := Trim(ifFail);
      if (ifFail<>'') and (ifFail[1] = ';') then  //quita delimitador
        ifFail := copyEx(ifFail,2);
    end;
  end;
end;
procedure tFaTokContent.AddOneInstruct(var exp: string; ifFalse: string = 'exit';
  TokTyp0: TSynHighlighterAttributes=nil);
//Agrega una y solo instrucción al token por contenido. Si encuentra más de una
//instrucción, genera una excepción.
var
  list: String;
  str: string;
  n: Integer;
  c: Char;
  expr: string;
  t: tFaRegExpType;
begin
  if exp='' then exit;
  //analiza
  expr := exp;   //guarda, porque se va a trozar
  t := ExtractRegExp(exp, str, list);
  case t of
  tregChars,    //Es de tipo lista de caracteres [...]
  tregChars01,  //Es de tipo lista de caracteres [...]?
  tregChars0_,  //Es de tipo lista de caracteres [...]*
  tregChars1_:  //Es de tipo lista de caracteres [...]+
    begin
      n := AddItem(t, '', ifFalse)-1;  //agrega
      Instrucs[n].TokTyp := TokTyp0;
      //Configura caracteres de contenido
      for c := #0 to #255 do Instrucs[n].Chars[c] := False;
      for c in list do Instrucs[n].Chars[c] := True;
    end;
  tregString: begin      //Es de tipo texto literal
      n := AddItem(t, '', ifFalse)-1;  //agrega
      Instrucs[n].TokTyp := TokTyp0;
      Instrucs[n].Text := str;
    end;
  else
    raise ESynFacilSyn.Create(ERR_UNSUPPOR_EXP_ + expr);
  end;
end;
procedure tFaTokContent.AddInstruct(exp: string; ifFalse: string = 'exit';
  TokTyp0: TSynHighlighterAttributes=nil);
//Agrega una instrucción para el procesamiento del token pro contenido.
//Solo se dbe indicar una instrucción, de otra forma se generará un error.
var
  expr: String;
begin
  expr := exp;   //guarda, porque se va a trozar
  AddOneInstruct(exp, ifFalse, TokTyp0);  //si hay error genera excepción
  //Si llegó aquí es porque se obtuvo una expresión válida, pero la
  //expresión continua.
  if exp<>'' then begin
    raise ESynFacilSyn.Create(ERR_UNSUPPOR_EXP_ + expr);
  end;
end;
procedure tFaTokContent.AddRegEx(exp: string);
{Agrega una expresión regular (un conjunto de instrucciones sin opciones de control), al
token por contenido. Las expresiones regulares deben ser solo las soportadas.
Ejemplos son:  "[0..9]*[\.][0..9]", "[A..Za..z]*"
Las expresiones se evalúan parte por parte. Si un token no coincide completamente con la
expresión regular, se considera al token, solamente hasta el punto en que coincide.
Si se produce algún error se generará una excepción.}
begin
  while exp<>'' do begin
    AddOneInstruct(exp);  //en principio, siempre debe coger una expresión
  end;
end;

{ TSynFacilSynBase }
function TSynFacilSynBase.BuscTokEspec(var mat: TArrayTokSpec; cad: string;
                         var n: integer; TokPos: integer = 0): boolean;
//Busca una cadena en una matriz TArrayTokSpec. Si la ubica devuelve el índice en "n".
var i : integer;
begin
  Result := false;
  if TokPos = 0 then begin //búsqueda normal
    for i := 0 to High(mat) do
      if mat[i].txt = cad then begin
        n:= i; exit(true);
      end
  end else begin  //búsqueda con TokPos
      for i := 0 to High(mat) do
        if (mat[i].txt = cad) and (TokPos = mat[i].TokPos) then begin
          n:= i; exit(true);
        end
  end;
end;
function TSynFacilSynBase.ToRegExp(interv: string): string;
//Reemplaza el contenido de un intervalo al formato de expresiones regualres.
//Los caracteres "..", cambian a "-" y el caracter "-", cambia a "\-"
begin
  interv := StringReplace(interv, '-', '\-',[rfReplaceAll]);
  Result := StringReplace(interv, '..', '-',[rfReplaceAll]);
end;
procedure TSynFacilSynBase.VerifDelim(delim: string);
//Verifica la validez de un delimitador para un token delimitado.
//Si hay error genera una excepción.
var c:char;
    tmp: string;
begin
  //verifica contenido
  if delim = '' then
    raise ESynFacilSyn.Create(ERR_TOK_DELIM_NULL);
  //verifica si inicia con caracter de identificador.
  if  delim[1] in charsIniIden then begin
    //Empieza como identificador. Hay que verificar que todos los demás caracteres
    //sean también de identificador, de otra forma no se podrá reconocer el token.
    tmp := copy(delim, 2, length(delim) );
    for c in tmp do
      if not CharsIdentif[c] then begin
        raise ESynFacilSyn.Create(format(ERR_TOK_DEL_IDE_ERR,[delim]));
      end;
  end;
end;
procedure TSynFacilSynBase.ValidateParamStart(Start: string; var ListElem: TStringList);
{Valida si la expresión del parámetro es de tipo <literal> o [<lista de cars>], de
otra forma generará una excepción.
Si es de tipo <literal>, valida que sea un delimitador válido.
Devuelve en "ListElem" una lista con con los caracteres (En el caso de [<lista de cars>])
o un solo elemento con una cadena (En el caso de <literal>). Por ejemplo:
Si Start = 'cadena', entonces se tendrá: ListElem = [ 'cadena' ]
Si Start = '[1..5]', entonces se tendrá: ListElem = ['0','1','2','3','4','5']
Si encuentra error, genera excepción.}
var
  t: tFaRegExpType;
  listChars: string;
  str: string;
  c: Char;
begin
  if Start= '' then raise ESynFacilSyn.Create(ERR_START_NO_EMPTY);
  t := ExtractRegExp(Start, str, listChars);
  ListElem.Clear;
  if Start<>'' then  //la expresión es más compleja
    raise ESynFacilSyn.Create(ERR_EXP_MUST_BE_BR);
  if t = tregChars then begin
    for c in listChars do begin
      ListElem.Add(c);
    end;
  end else if t = tregString then begin  //lista simple o literal cadena
    VerifDelim(str);   //valida reglas
    lisTmp.Add(str);
  end else //expresión de otro tipo
    raise ESynFacilSyn.Create(ERR_EXP_MUST_BE_BR);
end;
procedure TSynFacilSynBase.ValidAsigDelim(delAct, delNue: TFaTypeDelim; delim: string);
//Verifica si la asignación de delimitadores es válida. Si no lo es devuelve error.
begin
  if delAct = tdNull then  exit;  //No estaba inicializado, es totalente factible
  //valida asignación de delimitador
  if (delAct in [tdUniLin, tdMulLin]) and
     (delNue in [tdUniLin, tdMulLin]) then begin
    raise ESynFacilSyn.Create(Format(ERR_IDEN_ALREA_DEL,[delim]));
  end;
end;
function TSynFacilSynBase.KeyComp(var r: TTokSpec): Boolean; inline;
{Compara rápidamente una cadena con el token actual, apuntado por "fToIden".
 El tamaño del token debe estar en "fStringLen"}
var
  i: Integer;
  Temp: PChar;
begin
  Temp := fToIdent;
  if Length(r.txt) = fStringLen then begin  //primera comparación
    if (r.TokPos <> 0) and (r.TokPos<>posTok) then exit(false);  //no coincide
    Result := True;  //valor por defecto
    for i := 1 to fStringLen do begin
      if TabMayusc[Temp^] <> r.txt[i] then exit(false);
      inc(Temp);
    end;
  end else  //definitívamente es diferente
    Result := False;
end;
function TSynFacilSynBase.CreaBuscTokEspec(var mat: TArrayTokSpec; cad: string;
                                       var i:integer; TokPos: integer = 0): boolean;
{Busca o crea el token especial indicado en "cad". Si ya existe, devuelve TRUE y
 actualiza "i" con su posición. Si no existe. Crea el token especial y devuelve la
 referencia en "i". Se le debe indicar la tabla a buscar en "mat"}
var r:TTokSpec;
begin
  if not CaseSensitive then cad:= UpCase(cad);  //cambia caja si es necesario
  if BuscTokEspec(mat, cad, i, TokPos) then exit(true);  //ya existe, devuelve en "i"
  //no existe, hay que crearlo. Aquí se definen las propiedades por defecto
  r.txt:=cad;         //se asigna el nombre
  r.TokPos:=TokPos;   //se asigna ordinal del token
  r.tTok:=nil;        //sin tipo asignado
  r.typDel:=tdNull;   //no es delimitador
  r.dEnd:='';         //sin delimitador final
  r.pRange:=nil;      //sin función de rango
  r.folTok:=false;    //sin plegado de token
  r.bloIni:=false;    //sin plegado de bloque
  r.bloFin:=false;    //sin plegado de bloque
  r.secIni:=false;    //no es sección de bloque
  r.firstSec:=nil;     //inicialmente no abre ningún bloque

  i := High(mat)+1;   //siguiente posición
  SetLength(mat,i+1); //hace espacio
  mat[i] := r;        //copia todo el registro
  //sale indicando que se ha creado
  Result := false;
end;
//procesamiento de XML
function TSynFacilSynBase.ReadXMLParam(n: TDOMNode; nomb:string): TFaXMLatrib;
//Explora un nodo para ver si existe un atributo, y leerlo. Ignora la caja.
var i: integer;
    cad: string;
    atri: TDOMNode;
    r,g,b: integer;
  function EsEntero(txt: string; var num: integer): boolean;
  //convierte un texto en un número entero. Si es numérico devuelve TRUE
  var i: integer;
  begin
    Result := true;  //valor por defecto
    num := 0; //valor por defecto
    for i:=1 to length(txt) do begin
      if not (txt[i] in ['0'..'9']) then exit(false);  //no era
    end;
    //todos los dígitos son numéricos
    num := StrToInt(txt);
  end;
  function EsHexa(txt: string; var num: integer): boolean;
  //Convierte un texto en un número entero. Si es numérico devuelve TRUE
  var i: integer;
  begin
    Result := true;  //valor por defecto
    num := 0; //valor por defecto
    for i:=1 to length(txt) do begin
      if not (txt[i] in ['0'..'9','a'..'f','A'..'F']) then exit(false);  //no era
    end;
    //todos los dígitos son numéricos
    num := StrToInt('$'+txt);
  end;
begin
  Result.hay := false; //Se asume que no existe
  Result.val:='';      //si no encuentra devuelve vacío
  Result.bol:=false;   //si no encuentra devuelve Falso
  Result.n:=0;         //si no encuentra devuelve 0
  for i:= 0 to n.Attributes.Length-1 do begin
    atri := n.Attributes.Item[i];
    if UpCase(atri.NodeName) = UpCase(nomb) then begin
      Result.hay := true;          //marca bandera
      Result.val := atri.NodeValue;  //lee valor
      Result.bol := UpCase(atri.NodeValue) = 'TRUE';  //lee valor booleano
      cad := trim(atri.NodeValue);  //valor sin espacios
      //lee número
      if (cad<>'') and (cad[1] in ['0'..'9']) then  //puede ser número
        EsEntero(cad,Result.n); //convierte
      //lee color
      if (cad<>'') and (cad[1] = '#') and (length(cad)=7) then begin
        //es código de color. Lo lee de la mejor forma
        EsHexa(copy(cad,2,2),r);
        EsHexa(copy(cad,4,2),g);
        EsHexa(copy(cad,6,2),b);
        Result.col:=RGB(r,g,b);
      end else begin  //constantes de color
        case UpCase(cad) of
        'WHITE'      : Result.col:=rgb($FF,$FF,$FF);
        'SILVER'     : Result.col:=rgb($C0,$C0,$C0);
        'GRAY'       : Result.col:=rgb($80,$80,$80);
        'BLACK'      : Result.col:=rgb($00,$00,$00);
        'RED'        : Result.col:=rgb($FF,$00,$00);
        'MAROON'     : Result.col:=rgb($80,$00,$00);
        'YELLOW'     : Result.col:=rgb($FF,$FF,$00);
        'OLIVE'      : Result.col:=rgb($80,$80,$00);
        'LIME'       : Result.col:=rgb($00,$FF,$00);
        'GREEN'      : Result.col:=rgb($00,$80,$00);
        'AQUA'       : Result.col:=rgb($00,$FF,$FF);
        'TEAL'       : Result.col:=rgb($00,$80,$80);
        'BLUE'       : Result.col:=rgb($00,$00,$FF);
        'NAVY'       : Result.col:=rgb($00,$00,$80);
        'FUCHSIA'    : Result.col:=rgb($FF,$00,$FF);
        'PURPLE'     : Result.col:=rgb($80,$00,$80);

        'MAGENTA'    : Result.col:=rgb($FF,$00,$FF);
        'CYAN'       : Result.col:=rgb($00,$FF,$FF);
        'BLUE VIOLET': Result.col:=rgb($8A,$2B,$E2);
        'GOLD'       : Result.col:=rgb($FF,$D7,$00);
        'BROWN'      : Result.col:=rgb($A5,$2A,$2A);
        'CORAL'      : Result.col:=rgb($FF,$7F,$50);
        'VIOLET'     : Result.col:=rgb($EE,$82,$EE);
        end;
      end;
    end;
  end;
end;
procedure TSynFacilSynBase.CheckXMLParams(n: TDOMNode; listAtrib: string);
//Valida la existencia completa de los nodos indicados. Si encuentra alguno más
//genera excepción. Los nodos deben estar separados por espacios.
var i,j   : integer;
    atri  : TDOMNode;
    nombre, tmp : string;
    hay   : boolean;
begin
  //Carga lista de atributos
  lisTmp.Clear;  //usa lista temproal
  lisTmp.Delimiter := ' ';
  //StringReplace(listSym, #13#10, ' ',[rfReplaceAll]);
  lisTmp.DelimitedText := listAtrib;
  //Realiza la verificación
  for i:= 0 to n.Attributes.Length-1 do begin
    atri := n.Attributes.Item[i];
    nombre := UpCase(atri.NodeName);
    //verifica existencia
    hay := false;
    for j:= 0 to lisTmp.Count -1 do begin
      tmp := trim(lisTmp[j]);
      if nombre = UpCase(tmp) then begin
         hay := true; break;
      end;
    end;
    //verifica si no existe
    if not hay then begin   //Este atributo está demás
      raise ESynFacilSyn.Create(format(ERR_INVAL_ATTR_LAB,[atri.NodeName, n.NodeName]));
    end;
  end;
end;
//funciones rápidas para la tabla de métodos (tokens por contenido)
procedure TSynFacilSynBase.metTokCont(const tc: tFaTokContent); //inline;
//Procesa tokens por contenido
var
  n,i: Integer;
  posFin0: Integer;
  nf: Integer;
  tam1: Integer;
begin
  fTokenID := tc.TokTyp;   //pone tipo
//  repeat inc(posFin);
//  until not tc.CharsToken[fLine[posFin]];
  inc(posFin);  //para pasar al siguiente caracter
  n := 0;
  while n<tc.nInstruc do begin
    tc.Instrucs[n].posFin := posFin;  //guarda posición al iniciar
    case tc.Instrucs[n].expTyp of
    tregString: begin  //texo literal
        //rutina de comapración de cadenas
        posFin0 := posFin;  //para poder restaurar
        i := 1;
        tam1 := length(tc.Instrucs[n].Text)+1;  //tamaño +1
        while (i<tam1) and (tc.Instrucs[n].Text[i] = fLine[posFin]) do begin
          inc(posFin);
          inc(i);
        end;
        //verifica la coincidencia
        if i = tam1 then begin //cumple
          case tc.Instrucs[n].actionMatch of
          aomNext:;   //no hace nada, pasa al siguiente elemento
          aomExit: break;    //simplemente sale
          aomExitpar: begin  //sale con parámetro
            nf := tc.Instrucs[n].destOnMatch;   //lee posición final
            posFin := tc.Instrucs[nf].posFin;  //Debe moverse antes de salir
            break;
          end;
          aomMovePar:        //se mueve a una posición
            n := tc.Instrucs[n].destOnMatch;   //ubica posición
          end;
        end else begin      //no cumple
          posFin := posFin0;   //restaura posición
          case tc.Instrucs[n].actionFail of
          aomNext:;   //no hace nada, pasa al siguiente elemento
          aomExit: break;    //simplemente sale
          aomExitpar: begin  //sale con parámetro
            nf := tc.Instrucs[n].destOnFail;   //lee posición final
            posFin := tc.Instrucs[nf].posFin;  //Debe moverse antes de salir
            break;
          end;
          aomMovePar:        //se mueve a una posición
            n := tc.Instrucs[n].destOnFail;   //ubica posición
          end;
        end;
      end;
    tregChars: begin   //conjunto de caracteres: [ ... ]
        //debe existir solo una vez
        if tc.Instrucs[n].Chars[fLine[posFin]] then begin
          //cumple el caracter
          inc(posFin);  //pasa a la siguiente instrucción
          //Cumple el caracter
          case tc.Instrucs[n].actionMatch of
          aomNext:;   //no hace nada, pasa al siguiente elemento
          aomExit: break;    //simplemente sale
          aomExitpar: begin  //sale con parámetro
            nf := tc.Instrucs[n].destOnMatch;   //lee posición final
            posFin := tc.Instrucs[nf].posFin;  //Debe moverse antes de salir
            break;
          end;
          aomMovePar:        //se mueve a una posición
            n := tc.Instrucs[n].destOnMatch;   //ubica posición
          end;
        end else begin
          //no se encuentra ningún caracter de la lista
          case tc.Instrucs[n].actionFail of
          aomNext:;   //no hace nada, pasa al siguiente elemento
          aomExit: break;    //simplemente sale
          aomExitpar: begin  //sale con parámetro
            nf := tc.Instrucs[n].destOnFail;   //lee posición final
            posFin := tc.Instrucs[nf].posFin;  //Debe moverse antes de salir
            break;
          end;
          aomMovePar:        //se mueve a una posición
            n := tc.Instrucs[n].destOnFail;   //ubica posición
          end;
        end;
    end;
    tregChars01: begin   //conjunto de caracteres: [ ... ]?
        //debe existir cero o una vez
        if tc.Instrucs[n].Chars[fLine[posFin]] then begin
          inc(posFin);  //pasa a la siguiente instrucción
        end;
        //siempre cumplirá este tipo, no hay nada que verificar
        case tc.Instrucs[n].actionMatch of
        aomNext:;   //no hace nada, pasa al siguiente elemento
        aomExit: break;    //simplemente sale
        aomExitpar: begin  //sale con parámetro
          nf := tc.Instrucs[n].destOnMatch;   //lee posición final
          posFin := tc.Instrucs[nf].posFin;  //Debe moverse antes de salir
          break;
        end;
        aomMovePar:        //se mueve a una posición
          n := tc.Instrucs[n].destOnMatch;   //ubica posición
        end;
    end;
    tregChars0_: begin   //conjunto de caracteres: [ ... ]*
        //debe exitir 0 o más veces
        while tc.Instrucs[n].Chars[fLine[posFin]] do begin
          inc(posFin);
        end;
        //siempre cumplirá este tipo, no hay nada que verificar
      end;
    tregChars1_: begin   //conjunto de caracteres: [ ... ]+
        //debe existir una o más veces
        posFin0 := posFin;  //para poder comparar
        while tc.Instrucs[n].Chars[fLine[posFin]] do begin
          inc(posFin);
        end;
        if posFin>posFin0 then begin   //Cumple el caracter
          case tc.Instrucs[n].actionMatch of
          aomNext:;   //no hace nada, pasa al siguiente elemento
          aomExit: break;    //simplemente sale
          aomExitpar: begin  //sale con parámetro
            nf := tc.Instrucs[n].destOnMatch;   //lee posición final
            posFin := tc.Instrucs[nf].posFin;  //Debe moverse antes de salir
            break;
          end;
          aomMovePar:        //se mueve a una posición
            n := tc.Instrucs[n].destOnMatch;   //ubica posición
          end;
        end else begin   //No cumple
          case tc.Instrucs[n].actionFail of
          aomNext:;   //no hace nada, pasa al siguiente elemento
          aomExit: break;    //simplemente sale
          aomExitpar: begin  //sale con parámetro
            nf := tc.Instrucs[n].destOnFail;   //lee posición final
            posFin := tc.Instrucs[nf].posFin;  //Debe moverse antes de salir
            break;
          end;
          aomMovePar:        //se mueve a una posición
            n := tc.Instrucs[n].destOnFail;   //ubica posición
          end;
        end;
      end;
    end;
    inc(n);
  end;
end;
procedure TSynFacilSynBase.metTokCont1; //Procesa tokens por contenido 1
begin
  metTokCont(tc1);
end;
procedure TSynFacilSynBase.metTokCont2; //Procesa tokens por contenido 2
begin
  metTokCont(tc2);
end;
procedure TSynFacilSynBase.metTokCont3; //Procesa tokens por contenido 3
begin
  metTokCont(tc3);
end;
procedure TSynFacilSynBase.metTokCont4; //Procesa tokens por contenido 3
begin
  metTokCont(tc4);
end;
//Manejo de atributos
function TSynFacilSynBase.NewTokType(TypeName: string): TSynHighlighterAttributes;
//Crea un nuevo atributo y lo agrega al resaltador.
//No hay funciones para eliminar atributs creados.
begin
  Result := TSynHighlighterAttributes.Create(TypeName);
  AddAttribute(Result);   //lo registra
end;
procedure TSynFacilSynBase.CreateAttributes;
//CRea los atributos por defecto
begin
  //Elimina todos los atributos creados, los fijos y los del usuario.
  FreeHighlighterAttributes;
  { Crea los atributos que siempre existirán. }
  tkEol     := NewTokType('Eol');      //atributo de nulos
  tkSymbol  := NewTokType('Symbol');   //atributo de símbolos
  tkSpace   := NewTokType('Space');    //atributo de espacios.
  tkIdentif := NewTokType('Identifier'); //Atributo para identificadores.
  tkNumber  := NewTokType('Number');   //atributo de números
  tkNumber.Foreground := clFuchsia;
  tkKeyword := NewTokType('Key');      //atribuuto de palabras claves
//  tkKeyword.Style := [fsBold];
  tkKeyword.Foreground:=clGreen;
  tkString  := NewTokType('String');   //atributo de cadenas
  tkString.Foreground := clBlue;
  tkComment := NewTokType('Comment');  //atributo de comentarios
  tkComment.Style := [fsItalic];
  tkComment.Foreground := clGray;
end;
function TSynFacilSynBase.GetAttribByName(txt: string): TSynHighlighterAttributes;
//Devuelve el identificador de un atributo, recibiendo su nombre. Si no lo encuentra
//devuelve NIL.
var
  i: Integer;
begin
  Result := nil;     //por defecto es null
  txt := UpCase(txt);   //ignora la caja
  if txt = 'EOL'        then Result := tkEol else
  if txt = 'SYMBOL'     then Result := tkSymbol else
  if txt = 'SPACE'      then Result := tkSpace else
  if txt = 'IDENTIFIER' then Result := tkIdentif else
  if txt = 'NUMBER'     then Result := tkNumber else
  if txt = 'KEYWORD'    then Result := tkKeyword else
  if txt = 'STRING'     then Result := tkString else
  if txt = 'COMMENT'    then Result := tkComment
  else begin
    for i:=0 to AttrCount-1 do begin
        if Upcase(Attribute[i].Name) = txt then
          Result := Attribute[i];  //devuleve índice
    end;
  end;
end;
function TSynFacilSynBase.IsAttributeName(txt: string): boolean;
//Verifica si una cadena corresponde al nombre de un atributo.
begin
  //primera comparación
  if GetAttribByName(txt) <> nil then exit(true);
  //puede que haya sido "NULL"
  if UpCase(txt) = 'NULL' then exit(true);
  //definitivamente no es
  Result := False;
end;

var
  i: integer;
initialization
  //prepara definición de comodines
  bajos[0] := #127;
  for i:=1 to 127 do bajos[i] := chr(i);  //todo menos #0
  altos[0] := #128;
  for i:=1 to 128 do altos[i] := chr(i+127);

end.
