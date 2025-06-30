unit VirtualTrees.Obj;

interface

uses
  VirtualTrees,
  VirtualTrees.Types,
  System.Generics.Collections,
  System.Generics.Defaults,
  SysUtils;

type
  TBase = class
  private
    FNode: PVirtualNode;
  public
    property Node: PVirtualNode read FNode write FNode;
    constructor Create; virtual;
  end;

  TBaseClass = class of TBase;

  TBaseRecord = class(TBase)
  public
    class function CreateAsBase(BaseClass: TBaseClass): TBase;
    class function CreateClass<T: TBase>: T;
  end;

  vstHelper = class helper for TBaseVirtualTree
  public
    function obj<T: TBase>(ANode: PVirtualNode = nil; needCreate: boolean = true): T;
    function CurrentObj<T: TBase>: T;
  end;

implementation

{ TBase }

constructor TBase.Create;
begin
  FNode := nil;
end;

{ TBaseRecord }

class function TBaseRecord.CreateAsBase(BaseClass: TBaseClass): TBase;
begin
  Result := BaseClass.Create;
end;

class function TBaseRecord.CreateClass<T>: T;
begin
  Result := CreateAsBase(T) as T;
end;

{ vstHelper }

function vstHelper.CurrentObj<T>: T;
begin
  if Assigned(FocusedNode) then
    Result := obj<T>(FocusedNode, false)
  else
    Result := nil;
end;

function vstHelper.obj<T>(ANode: PVirtualNode; needCreate: boolean): T;
var
  v: PVirtualNode;
begin
  Result := nil;
  V := nil;
  if (ANode = nil) and needCreate then
    V := AddChild(rootNode)
  else begin
    if ANode <> nil then
    begin
      V := ANode;
      Result := T(GetNodeData(V)^);
    end;
  end;

  if Assigned(V) and not Assigned(Result) and needCreate then
  begin
    Result := TBaseRecord.CreateClass<T>;
    T(GetNodeData(V)^) := Result;
    Result.FNode := V;
  end;
end;

end.
