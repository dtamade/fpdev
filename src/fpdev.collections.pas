unit fpdev.collections;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.collections

容器


## 声明

转发或者用于自己项目请保留本项目的版权声明,谢谢.

fafafaStudio
Email:dtamade@gmail.com
QQ群:685403987  QQ:179033731

}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  sysutils;

///
/// 容器内存分配器
///

type

  allocator_getMem_t     = function(aSize: PtrUInt): Pointer;
  allocator_allocMem_t   = allocator_getMem_t;
  allocator_reAllocMem_t = function(var aMem: Pointer; aSize: PtrUInt): Pointer;
  allocator_freeMem_t    = procedure(aPtr: Pointer);


  pallocator_t = ^allocator_t;

{ allocator_t 内存分配器 }

 allocator_t  = record
    getMem:      allocator_getMem_t;
    allocMem:    allocator_allocMem_t;
    reallocMem: allocator_reAllocMem_t;
    freeMem:    allocator_freeMem_t;
  end;

function allocator_create(
  aGetMem: allocator_getMem_t;
  aAllocMem: allocator_allocMem_t;
  aReallocMem: allocator_reAllocMem_t;
  aFreeMem: allocator_freeMem_t
): pallocator_t;
procedure allocator_init(
  aAllocator: pallocator_t;
  aGetMem: allocator_getMem_t;
  aAllocMem: allocator_allocMem_t;
  aReallocMem: allocator_reAllocMem_t;
  aFreeMem: allocator_freeMem_t
);
procedure allocator_destroy(aAllocator: pallocator_t);
function allocator_getMem(
  aAllocator: pallocator_t;
  aSize: PtrUInt
): Pointer; {$IFDEF FAFAFA_COLLECTIONS_INLINE}inline;{$ENDIF}
function allocator_allocMem(
  aAllocator: pallocator_t;
  aSize: PtrUInt
): Pointer; {$IFDEF FAFAFA_COLLECTIONS_INLINE}inline;{$ENDIF}
function allocator_reallocMem(
  aAllocator: pallocator_t;
  var aMem: Pointer;
  aSize: PtrUInt
): Pointer; {$IFDEF FAFAFA_COLLECTIONS_INLINE}inline;{$ENDIF}
procedure allocator_freeMem(aAllocator: pallocator_t; aPtr: Pointer); {$IFDEF FAFAFA_COLLECTIONS_INLINE}inline;{$ENDIF}

{**
 * allocator_rtl
 *
 * @desc 获取默认的rtl内存分配器
 *
 * @return 返回默认的内存分配器
 *}
function  allocator_rtl: pallocator_t; inline;


type

  { IAllocator 内存分配器接口 }

  IAllocator = interface
  ['{E7F77971-51EC-4272-A12B-F378E1806083}']
    function  GetMem(aSize: PtrUInt): Pointer;
    function  AllocMem(aSize: PtrUInt): Pointer;
    function  ReallocMem(var aMem: Pointer; aSize: PtrUInt): Pointer;
    procedure FreeMem(aPtr: Pointer);
  end;

  { TAllocator 内存分配器 }

  TAllocator = class(TInterfacedObject, IAllocator)
  private
    FAllocatorInternal: pallocator_t;
    FAllocator:         pallocator_t;
  private
    class var FRTLAllocator: TAllocator;
  public
    class function   RTLAllocator: TAllocator; static; {$IFDEF FAFAFA_COLLECTIONS_INLINE}inline;{$ENDIF}
    class destructor Destroy;
  public
    constructor CreateFromAllocator(aAllocator: pallocator_t); overload;
    constructor Create(
      aGetMem: allocator_getMem_t;
      aAllocMem: allocator_allocMem_t;
      aReallocMem: allocator_reAllocMem_t;
      aFreeMem: allocator_freeMem_t
    ); overload;
    destructor  Destroy; override;

    function  GetAllocator: pallocator_t; {$IFDEF FAFAFA_COLLECTIONS_INLINE}inline;{$ENDIF}
    function  GetMem(aSize: PtrUInt): Pointer; {$IFDEF FAFAFA_COLLECTIONS_INLINE}inline;{$ENDIF}
    function  AllocMem(aSize: PtrUInt): Pointer; {$IFDEF FAFAFA_COLLECTIONS_INLINE}inline;{$ENDIF}
    function  ReallocMem(var aMem: Pointer; aSize: PtrUInt): Pointer; {$IFDEF FAFAFA_COLLECTIONS_INLINE}inline;{$ENDIF}
    procedure FreeMem(aPtr: Pointer); {$IFDEF FAFAFA_COLLECTIONS_INLINE}inline;{$ENDIF}

    property  Allocator: pallocator_t read GetAllocator;
  end;

///
/// 容器基础
///

type

  TCollection = class;

  { ICollection 容器接口 }

  ICollection = interface
  ['{4185E60A-B6D6-49B4-A4BD-07F41A706014}']
    {**
     * GetCount
     *
     * @desc 获取容器元素数量
     *
     * @return 返回容器元素数量
     *}
    function  GetCount: SizeUInt;

    {**
     * GetData
     *
     * @desc 获取容器额外数据指针
     *
     * @return 返回容器额外数据指针
     *}
    function  GetData: Pointer;

    {**
     * SetData
     *
     * @desc 设置容器额外数据指针
     *
     * @params
     *  - aData 要设置的额外数据指针
     *}
    procedure SetData(aData: Pointer);

    {**
     * GetAllocator
     *
     * @desc 获取容器内存分配器
     *
     * @return 返回容器内存分配器
     *}
    function  GetAllocator: TAllocator;

    {**
     * IsEmpty
     *
     * @desc 判断容器是否为空
     *
     * @return 返回容器是否为空
     *}
    function  IsEmpty: Boolean;

    {**
     * Clear
     *
     * @desc 清空容器
     *}
    procedure Clear;

    {**
     * Clone
     *
     * @desc 克隆容器
     *
     * @return 返回克隆后的容器
     *}
    function  Clone: TCollection;

    {**
     * Equals
     *
     * @desc 判断容器是否相等
     *
     * @params
     *  - aCollection 要比较的容器
     *
     * @return 返回容器是否相等
     *}
    function  Equals(aCollection: TCollection): Boolean;

    { Container cursor
      Basic iteration interface for base container
      This is a set of generic interfaces for traversing container elements. Due to its implementation relying on virtual functions (cannot be inlined), performance is not optimal, but it maintains component flexibility
    }

    {**
     * CursorSave
     *
     * @desc Save container cursor
     *}
    procedure CursorSave;

    {**
     * CursorRestore
     *
     * @desc Restore container cursor
     *}
    procedure CursorRestore;

    {**
     * CursorCurrentPtr
     *
     * @desc Get current element pointer of container
     *
     * @return Returns current element pointer of container
     *}
    function  CursorCurrentPtr: Pointer;

    {**
     * CursorNext
     *
     * @desc Move container cursor to next element
     *
     * @return Returns whether cursor was successfully moved
     *}
    function  CursorNext: Boolean;

    {**
     * CursorGoFirst
     *
     * @desc Move container cursor to first element
     *
     * @return Returns whether cursor was successfully moved
     *}
    function  CursorGoFirst: Boolean;

    property  Count:     SizeUInt      read GetCount;
    property  Data:      Pointer      read GetData write SetData;
    property  Allocator: TAllocator   read GetAllocator;
  end;

  { TCollection 容器基类 }

  TCollection = class(TInterfacedObject, ICollection)
  private
    FAllocator:         TAllocator;
    FData:              Pointer;
  public
    constructor Create; overload;
    constructor Create(aAllocator: TAllocator); overload;
    constructor Create(aAllocator: TAllocator; aData: Pointer); overload; virtual;
    destructor  Destroy; override;

    function  GetCount: SizeUInt; virtual;abstract;
    function  GetData: Pointer; {$IFDEF FAFAFA_COLLECTIONS_INLINE}inline;{$ENDIF}
    procedure SetData(aData: Pointer); {$IFDEF FAFAFA_COLLECTIONS_INLINE}inline;{$ENDIF}
    function  GetAllocator: TAllocator; {$IFDEF FAFAFA_COLLECTIONS_INLINE}inline;{$ENDIF}

    function  IsEmpty: Boolean; virtual;
    procedure Clear; virtual; abstract;

    function  Clone: TCollection; virtual; abstract;
    function  Equals(aCollection: TCollection): Boolean; virtual; abstract; reintroduce;

    function  CursorCurrentPtr: Pointer; virtual; abstract;
    procedure CursorSave; virtual;
    procedure CursorRestore; virtual;
    function  CursorNext: Boolean; virtual; abstract;
    function  CursorGoFirst: Boolean; virtual; abstract;

    property  Count:     SizeUInt    read GetCount;
    property  Data:      Pointer    read GetData write SetData;
    property  Allocator: TAllocator read GetAllocator;
  end;


implementation

function getMem_rtl(aSize: PtrUInt): Pointer; inline;
begin
  Result := GetMem(aSize);
end;

function allocMem_rtl(aSize: PtrUInt): Pointer; inline;
begin
  Result := AllocMem(aSize);
end;

function reallocMem_rtl(var aMem: Pointer; aSize: PtrUInt): Pointer; inline;
begin
  Result := ReallocMem(aMem, aSize);
end;

procedure freeMem_rtl(aPtr: Pointer); inline;
begin
  FreeMem(aPtr);
end;

var

  allocator_rtl_global: allocator_t=(
    getMem:     @getMem_rtl;
    allocMem:   @allocMem_rtl;
    reallocMem: @reallocMem_rtl;
    freeMem:    @freeMem_rtl;
  );

function allocator_create(aGetMem: allocator_getMem_t;
  aAllocMem: allocator_allocMem_t; aReallocMem: allocator_reAllocMem_t;
  aFreeMem: allocator_freeMem_t): pallocator_t;
begin
  Result := aGetMem(SizeOf(allocator_t));
  allocator_init(Result, aGetMem, aAllocMem, aReallocMem, aFreeMem);
end;

procedure allocator_init(aAllocator: pallocator_t; aGetMem: allocator_getMem_t;
  aAllocMem: allocator_allocMem_t; aReallocMem: allocator_reAllocMem_t;
  aFreeMem: allocator_freeMem_t);
begin
  aAllocator^.getMem := aGetMem;
  aAllocator^.allocMem := aAllocMem;
  aAllocator^.reallocMem := aReallocMem;
  aAllocator^.freeMem := aFreeMem;
end;

procedure allocator_destroy(aAllocator: pallocator_t);
begin
  aAllocator^.freeMem(aAllocator);
end;

function allocator_getMem(aAllocator: pallocator_t; aSize: PtrUInt): Pointer;
begin
  Result := aAllocator^.getMem(aSize);
end;

function allocator_allocMem(aAllocator: pallocator_t; aSize: PtrUInt): Pointer;
begin
  Result := aAllocator^.allocMem(aSize);
end;

function allocator_reallocMem(aAllocator: pallocator_t; var aMem: Pointer; aSize: PtrUInt): Pointer;
begin
  Result := aAllocator^.reallocMem(aMem, aSize);
end;

procedure allocator_freeMem(aAllocator: pallocator_t; aPtr: Pointer);
begin
  aAllocator^.freeMem(aPtr);
end;

function allocator_rtl: pallocator_t;
begin
  Result := @allocator_rtl_global;
end;

class function TAllocator.RTLAllocator: TAllocator;
begin
  if FRTLAllocator = nil then
    FRTLAllocator := TAllocator.CreateFromAllocator(allocator_rtl());

  Result := FRTLAllocator;
end;

class destructor TAllocator.Destroy;
begin
  if FRTLAllocator <> nil then
    FRTLAllocator.Free;
end;

constructor TAllocator.CreateFromAllocator(aAllocator: pallocator_t);
begin
  inherited Create;
  FAllocator := aAllocator;
end;

constructor TAllocator.Create(aGetMem: allocator_getMem_t;
  aAllocMem: allocator_allocMem_t; aReallocMem: allocator_reAllocMem_t;
  aFreeMem: allocator_freeMem_t);
begin
  FAllocatorInternal := allocator_create(aGetMem, aAllocMem, aReallocMem, aFreeMem);
  CreateFromAllocator(FAllocatorInternal);
end;

destructor TAllocator.Destroy;
begin
  if FAllocatorInternal <> nil then
    allocator_destroy(FAllocatorInternal);
  inherited Destroy;
end;

function TAllocator.GetAllocator: pallocator_t;
begin
  Result := FAllocator;
end;

function TAllocator.GetMem(aSize: PtrUInt): Pointer;
begin
  Result := FAllocator^.getMem(aSize);
end;

function TAllocator.AllocMem(aSize: PtrUInt): Pointer;
begin
  Result := FAllocator^.allocMem(aSize);
end;

procedure TAllocator.FreeMem(aPtr: Pointer);
begin
  FAllocator^.freeMem(aPtr);
end;

function TAllocator.ReallocMem(var aMem: Pointer; aSize: PtrUInt): Pointer;
begin
  Result := FAllocator^.reallocMem(aMem, aSize);
end;


constructor TCollection.Create;
begin
  Create(TAllocator.RTLAllocator, nil);
end;

constructor TCollection.Create(aAllocator:TAllocator);
begin
  Create(aAllocator, nil);
end;

constructor TCollection.Create(aAllocator:TAllocator; aData:Pointer);
begin
  inherited Create;

  if aAllocator = nil then
    aAllocator := TAllocator.RTLAllocator;

  FAllocator := aAllocator;
  FData := aData;
end;

destructor TCollection.Destroy;
begin
  inherited Destroy;
end;

function TCollection.GetData:Pointer;
begin
  Result := FData;
end;

procedure TCollection.SetData(aData:Pointer);
begin
  FData := aData;
end;

function TCollection.GetAllocator:TAllocator;
begin
  Result := FAllocator;
end;

function TCollection.IsEmpty:Boolean;
begin
  Result := (GetCount = 0);
end;

procedure TCollection.CursorSave;
begin
  // nothing
end;

procedure TCollection.CursorRestore;
begin
  // nothing
end;



end.
