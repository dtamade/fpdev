unit fpdev.params;

interface

type

  TFPDevParams = class
  private
    FParams: array of string;
  public
    constructor Create(const aParams: array of string);

    function IsEmpty:boolean;
    function Peek:string;
    function Pop:string;

    property Count: Integer read GetCount;
  end;

implementation

end.
