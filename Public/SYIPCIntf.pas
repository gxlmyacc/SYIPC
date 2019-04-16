unit SYIPCIntf;

interface

const
  IPC_TIMEOUT           = 1000;
  IPC_TIMEOUT_OPENCLOSE = 100;
  IPC_CHAR_SIZE         = SizeOf(WideChar);
  IPC_SESSIONNAME_SIZE  = 40;
  IPC_CALLMETHOD_SIZE   = 100;
  
type
  /// <summary>
  /// IPC消息的数据类型，用于标识IIPCMessage中的数据类型
  /// </summary>
  TIPCMessageDataType =  Byte; //(
const
  /// <summary>
  /// 预定义消息类型
  /// </summary>
    mdtUnknown    = 0;
    mdtString     = 1;
    mdtInteger    = 2;
    mdtBoolean    = 3;
    mdtDouble     = 4;
    mdtCurrency   = 5;
    mdtDateTime   = 6;
    mdtFile       = 7;

    mdtCall       = 10;
    mdtCallReturn = 11;
    mdtError      = 12;
    //mdtCallback   = 13;
        
  /// <summary>
  /// 用户自定义消息类型的起始编号
  /// </summary>
    mdtCustomBase = 56;
  /// <summary>
  /// 用户自定义消息类型的最大编号
  /// </summary>
    mdtCustomMax  = 255;
  //);
        
type
  IIPCMessage = interface;
  IIPCServer = interface;
  IIPCClient = interface;

  /// <summary>
  /// IPC状态，用于IPCServer/IPCClient的OnMessage事件中
  /// </summary>
  TIPCState = (
    isAfterOpen,
    isAfterClose,
    isConnect,
    isDisconnect,
    isReceiveData
  );

  TMessageData = {$IF CompilerVersion > 18.5}PByte{$ELSE}PAnsiChar{$IFEND};

  /// <summary>
  /// IPC消息数组
  /// </summary>
  TIPCMessageArray = array of IIPCMessage;
  /// <summary>
  /// IPC消息接口，该接口封装了发送/接收的数据，方便对消息数据进行处理
  /// </summary>
  IIPCMessage = interface
  ['{B866075F-200A-49AC-9992-8403FE9A3108}']
    function GetData: TMessageData;
    function GetDataSize: Cardinal;
    function GetDataType: TIPCMessageDataType;
    function GetReadOnly: Boolean;
    function GetSenderID: Cardinal;
    function GetTopic: Byte;
    function GetI: Int64;
    function GetB: Boolean;
    function GetD: Double;
    function GetC: Currency;
    function GetDT: TDateTime;
    function GetS: WideString;
    function GetTag: Pointer;
    procedure SetDataType(const Value: TIPCMessageDataType);
    procedure SetSenderID(const Value: Cardinal);
    procedure SetI(const Value: Int64);
    procedure SetB(const Value: Boolean);
    procedure SetD(const Value: Double);
    procedure SetC(const Value: Currency);
    procedure SetDT(const Value: TDateTime);
    procedure SetS(const Value: WideString);
    procedure SetTopic(const Value: Byte);
    procedure SetTag(const Value: Pointer);
    
    function Implementor: Pointer;

    /// <summary>
    /// 将当前IPC消息克隆一份
    /// </summary>
    function  Clone: IIPCMessage;
    /// <summary>
    /// 清空数据，该方法将会清空已设置的数据，Data会变成nil、DataType会变为mdtCustom
    /// </summary>
    procedure Clear;
    /// <summary>
    /// 设置类型为mdtCustom的IPC消息的数据
    /// </summary>
    /// <param name="AData">数据的起始指针地址</param>
    /// <param name="ADataSize">数据的长度(字节)</param>
    /// <remarks>
    /// 该函数内部会对AData的数据进行拷贝，所以在调用这个方法后AData即可销毁
    /// </remarks>
    procedure SetData(const AData: TMessageData; const ADataSize: Cardinal); overload;
    /// <summary>
    /// 设置IPC消息的数据(可自定义数据类型)
    /// </summary>
    /// <param name="AData">数据的起始指针地址</param>
    /// <param name="ADataSize">数据的长度(字节)</param>
    /// <param name="ADataType">数据类型</param>
    /// <remarks>
    /// 该函数内部会对AData的数据进行拷贝，所以在调用这个方法后AData即可销毁
    /// </remarks>
    procedure SetData(const AData: TMessageData; const ADataSize: Cardinal; const ADataType: TIPCMessageDataType); overload;
    /// <summary>
    /// 向IPC数据里追加数据(该方法【不会】修改已设置的DataType值)
    /// </summary>
    /// <param name="AData">待追加的数据的起始指针地址</param>
    /// <param name="ADataSize">待追加的数据的长度(字节)</param>
    procedure Add(const AData: TMessageData; const ADataSize: Cardinal); overload;
    /// <summary>
    /// 向IPC数据里追加数据(该方法【会】修改已设置的DataType值)
    /// </summary>
    /// <param name="AData">待追加的数据的起始指针地址</param>
    /// <param name="ADataSize">待追加的数据的长度(字节)</param>
    /// <param name="ADataType">数据类型</param>
    procedure Add(const AData: TMessageData; const ADataSize: Cardinal; const ADataType: TIPCMessageDataType); overload;
    /// <summary>
    /// 向IPC数据里追加字符串
    /// </summary>
    /// <param name="AData">待追加的字符串(unicode编码)</param>
    /// <remarks>
    /// 该函数会自动设置DataType为mdtString
    /// </remarks>
    procedure Add(const AData: WideString); overload;
    /// <summary>
    /// 从文件中加载IPC消息数据，在加载之前会清空已设置的消息数据
    /// </summary>
    /// <param name="AFileName">待加载的文件名</param>
    /// <param name="ADataType">指定加载后IPC消息的数据类型</param>
    /// <returns>加载是否成功</returns>
    function LoadFromFile(const AFileName: WideString; const ADataType: TIPCMessageDataType = mdtFile): Boolean;
    /// <summary>
    /// 将IPC消息的数据保存到文件中
    /// </summary>
    /// <param name="AFileName">待保存的文件名</param>
    /// <param name="bFailIfExist">如果为True，则保存时如果文件已存在则直接返回False。</param>
    /// <returns></returns>
    function SaveToFile(const AFileName: WideString; const bFailIfExist: Boolean = False): Boolean;

    /// <summary>
    /// 标识该IPC消息的数据是否可以被修改，如果ReadOnly数据为False，则所有与数据
    /// 修改有关的函数调用都会失败。
    /// </summary>
    property ReadOnly: Boolean read GetReadOnly;
    property S: WideString read GetS write SetS;
    property I: Int64 read GetI write SetI;
    property B: Boolean read GetB write SetB;
    property D: Double read GetD write SetD;
    property C: Currency read GetC write SetC;
    property DT: TDateTime read GetDT write SetDT;
    property Data: TMessageData read GetData;
    property DataSize: Cardinal read GetDataSize;
    property DataType: TIPCMessageDataType read GetDataType write SetDataType;
    property SenderID: Cardinal read GetSenderID write SetSenderID;
    /// <summary>
    /// 用户自定义主题，该值可以被IPC传递
    /// </summary>
    property Topic: Byte read GetTopic write SetTopic;
    /// <summary>
    /// 一个扩展字段，用户可以用它存储任何数据，注：该值不会被IPC传递
    /// </summary>
    property Tag: Pointer read GetTag write SetTag;
  end;

  /// <summary>
  /// IPC消息队列，用于缓存IPCServer/IPCClient的异步消息
  /// </summary>
  PIIPCMessageQueue = ^IIPCMessageQueue;
  IIPCMessageQueue = interface
  ['{0BA65859-6A75-42DB-99E0-237C45358AD1}']
    function  GetCount: Integer;
    function  GetItem(const Index: Integer): IIPCMessage;
    /// <summary>
    /// 向队列添加一条消息
    /// </summary>
    /// <param name="AItem">添加一条消息</param>
    /// <returns></returns>
    function  Push(const AItem: IIPCMessage): Integer;
    /// <summary>
    /// 如果队列中有消息，则取出第一条消息，并将这条消息从队列中移除
    /// </summary>
    /// <param name="AItem">取出的消息，如果没有消息，则为nil。</param>
    /// <returns>如果队列中有消息，则返回True, 否则返回False</returns>
    function  Pop(out AItem: IIPCMessage): Boolean;
    /// <summary>
    /// 如果队列中有消息，则取出第一条消息
    /// </summary>
    /// <returns>队列中的第一条消息，如果没有则为nil</returns>
    function  Peek: IIPCMessage;
    /// <summary>
    /// 清除队列中的所有消息
    /// </summary>
    procedure Clear;
    /// <summary>
    /// 当前队列中的消息数量
    /// </summary>
    property Count: Integer read GetCount;
    /// <summary>
    /// 根据索引从队列中取消息，该属性可用于遍历消息队列中的消息
    /// </summary>
    property Item[const Index: Integer]: IIPCMessage read GetItem; default;
  end;
      
  /// <summary>
  /// IPCServer的消息处理事件
  /// </summary>
  TIPCServerMessageEvent = procedure (const AServer: IIPCServer; const AState: TIPCState;
    const ASenderID: Cardinal; const AMessage: IIPCMessage) of object;
  /// <summary>
  /// IPCClient的消息处理事件
  /// </summary>
  TIPCClientMessageEvent = procedure (const AClient: IIPCClient; const AState: TIPCState;
    const ASenderID: Cardinal; const AMessage: IIPCMessage) of object;

  /// <summary>
  /// IPC服务端接口，该接口封装了IPC服务端的相关功能
  /// </summary>
  /// <example>
  /// <code>
  ///   LServer := CreateIPCServer("AIPCSessionName");
  ///   LServer.OnMessage := DoServerMessageMethod;
  ///   LServer.Open;
  ///   if not LServer.Send(iClientID, "Hello, I'm server.") then
  ///     LogWarning("发送数据失败");
  ///   if not LServer.Broadcast("Hello, I'm server.") then
  ///     LogWarning("广播数据失败");
  /// </code>
  /// </example>
  IIPCServer = interface
  ['{463CF8CA-7115-493B-96A0-03730970D622}']
    function GetActive: Boolean;
    function GetReciveMessageInThread: Boolean;
    function GetReciveMessageToQueue: Boolean;
    function GetSessionName: WideString;
    function GetSessionHandle: Cardinal;
    function GetID: Cardinal;
    function GetClientCount: Integer;
    function GetClientInfos: WideString;
    function GetLastClientID: Cardinal;
    function GetReciveQueue: PIIPCMessageQueue;
    function GetOnMessage: TIPCServerMessageEvent;
    function GetDispatch: IDispatch;
    function GetTag: Pointer;
    function GetLastError: WideString;
    procedure SetActive(const Value: Boolean);
    procedure SetReciveMessageInThread(const Value: Boolean);
    procedure SetReciveMessageToQueue(const Value: Boolean);
    procedure SetSessionName(const Value: WideString);
    procedure SetOnMessage(const Value: TIPCServerMessageEvent);
    procedure SetDispatch(const Value: IDispatch);
    procedure SetTag(const Value: Pointer);
    
    function Implementor: Pointer;
    /// <summary>
    /// 检查指定SessionName是否已经存在
    /// </summary>
    /// <param name="ASessionName">待检查的SessionName</param>
    /// <returns></returns>
    function IsExist(const ASessionName: WideString): Boolean;
    /// <summary>
    /// 创建一个IPC会话，等待客户端的连接，在调用该方法之前需要设置
    /// SessionName属性。
    /// </summary>
    /// <returns>创建是否成功</returns>
    function Open: Boolean; overload;
    /// <summary>
    /// 创建一个IPC会话
    /// </summary>
    /// <param name="ASessionName">一个唯一的IPC会话名称</param>
    /// <returns>创建是否成功</returns>
    function Open(const ASessionName: WideString): Boolean; overload;
    /// <summary>
    /// 关闭IPC服务端会话
    /// </summary>
    procedure Close;
    /// <summary>
    /// 判断指定的客户端ID是否连接到了本服务端
    /// </summary>
    /// <param name="AClientID"></param>
    /// <returns>如果该客户端连接到了本服务端则返回True，否则返回False</returns>
    function IsConnect(const AClientID: Cardinal): Boolean;
    /// <summary>
    /// 检查IPCServer有没有实现指定的方法
    /// </summary>
    /// <param name="AClientID">待检查的客户端ID</param>
    /// <param name="AMethodName">待检查的方法名</param>
    /// <returns></returns>
    function MethodExist(const AClientID: Cardinal; const AMethodName: WideString): Boolean;
    /// <summary>
    /// 调用连接的IPCServer绑定的Dispatch对象的方法
    /// </summary>
    /// <param name="AClientID">待调用的客户端ID</param>
    /// <param name="AMethodName">方法名</param>
    /// <param name="AParams">调用参数(注：参数仅支持IIPCMessage支持的类型)</param>
    /// <param name="ATimeOut">调用超时时间</param>
    /// <returns>服务端方法返回的结果</returns>
    function TryCall(const AClientID: Cardinal; const AMethodName: WideString; const AParams: array of OleVariant;
      out AResult: IIPCMessage; const ATimeOut: Cardinal): Boolean;
    function TryCallEx(const AClientID: Cardinal; const AMethodName: WideString; const AParams: array of IIPCMessage;
      out AResult: IIPCMessage; const ATimeOut: Cardinal): Boolean;
    function Call(const AClientID: Cardinal; const AMethodName: WideString;
      const AParams: array of OleVariant; const ATimeOut: Cardinal = IPC_TIMEOUT): IIPCMessage;
    function CallEx(const AClientID: Cardinal; const AMethodName: WideString;
      const AParams: array of IIPCMessage; const ATimeOut: Cardinal = IPC_TIMEOUT): IIPCMessage;
    /// <summary>
    /// 向指定客户端发送数据，以下有一系列的不同数据类型的重载函数
    /// </summary>
    /// <param name="AClientID">要发送的客户端ID</param>
    /// <param name="AData">待发送的数据</param>
    /// <param name="ATimeOut">等待客户端反馈的最大时间(超时时间)</param>
    /// <returns>
    ///  处理结果：
    /// <list type="Boolean">
    /// <item>
    /// <term>False</term>
    /// <description>发送失败</description>
    /// </item>
    /// <item>
    /// <term>True</term>
    /// <description>发送成功</description>
    /// </item>
    /// </list>
    /// </returns>
    function Send(const AClientID: Cardinal; const AData: IIPCMessage; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AClientID: Cardinal; const AData: Pointer; const ADataLen: Cardinal; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AClientID: Cardinal; const AData: WideString; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AClientID: Cardinal; const AData: Int64; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AClientID: Cardinal; const AData: Boolean; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AClientID: Cardinal; const AData: Double; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function SendC(const AClientID: Cardinal; const AData: Currency; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean;
    function SendDT(const AClientID: Cardinal; const AData: TDateTime; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean;
    function SendFile(const AClientID: Cardinal; const AFileName: WideString; ATimeOut: Cardinal = IPC_TIMEOUT): Boolean;

    /// <summary>
    /// 向所有连接到本服务端的客户端发送(广播)数据，以下有一系列的不同数据类型的重载函数
    /// </summary>
    /// <param name="AData">待发送的数据</param>
    /// <param name="AExclude">广播时排除的客户端ID(即不向这个客户端发送消息)</param>
    /// <param name="ATimeOut">超时时间</param>
    /// <returns>
    ///  处理结果：
    /// <list type="Boolean">
    /// <item>
    /// <term>False</term>
    /// <description>发送超时</description>
    /// </item>
    /// <item>
    /// <term>True</term>
    /// <description>发送成功</description>
    /// </item>
    /// </list>
    /// </returns>
    function Broadcast(const AData: IIPCMessage; const AExclude: Cardinal = 0; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Broadcast(const AData: Pointer; const ADataLen: Cardinal; const AExclude: Cardinal = 0; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Broadcast(const AData: WideString; const AExclude: Cardinal = 0; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function BroadcastFile(const AFileName: WideString; const AExclude: Cardinal = 0; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean;
    /// <summary>
    /// 会话打开后创建的服务ID
    /// </summary>
    property ID: Cardinal read GetID;
    /// <summary>
    /// IPC会话名称(频道)，客户端和服务端通过这个名称来区分是否连接配对
    /// </summary>
    property SessionName: WideString read GetSessionName write SetSessionName;
    /// <summary>
    /// IPC会话句柄，客户端和服务端通过这个句柄来进行连接配对
    /// </summary>
    property SessionHandle: Cardinal read GetSessionHandle;
    /// <summary>
    /// 获取/设置当前IPC会话状态(创建/关闭，相当于调用Open/Close方法)
    /// </summary>
    property Active: Boolean read GetActive write SetActive;
    /// <summary>
    /// 在OnMessage事件中接收数据状态的处理是否放在一个独立线程中
    /// </summary>
    /// <list type="Boolean">
    /// <item>
    /// <term>False(默认)</term>
    /// <description>在OnMessage事件在主线程中处理接收的数据</description>
    /// </item>
    /// <item>
    /// <term>True</term>
    /// <description>OnMessage事件在一个独立线程中处理接收的数据</description>
    /// </item>
    /// </list>
    property ReciveMessageInThread: Boolean read GetReciveMessageInThread write SetReciveMessageInThread;
    /// <summary>
    /// 是否将接受到的消息放入消息队列，如果为True时，OnMessage事件将接受不到IsReciveMessage消息
    /// </summary>
    property ReciveMessageToQueue: Boolean read GetReciveMessageToQueue write SetReciveMessageToQueue;
    /// <summary>
    /// 当前连接的客户端数量
    /// </summary>
    property ClientCount: Integer read GetClientCount;
    /// <summary>
    /// 客户端连接信息，该属性是一个JSON字符串，格式为：[ { clientID: XXXXXX }, { clientID: XXXXXX } ]
    /// </summary>
    property ClientInfos: WideString read GetClientInfos;
    /// <summary>
    /// 最近一次发送消息的客户端
    /// </summary>
    property LastClientID: Cardinal read GetLastClientID;
    /// <summary>
    /// 消息队列，如果ReciveMessageToQueue为True，则接收到的消息将放入该队列中，而不是调用OnMessage事件
    /// </summary>
    property ReciveQueue: PIIPCMessageQueue read GetReciveQueue;
    /// <summary>
    /// IPC服务端状态与接收数据的事件处理器
    /// </summary>
    property OnMessage: TIPCServerMessageEvent read GetOnMessage write SetOnMessage;
    /// <summary>
    /// 绑定的IDispatch对象，IPC另一端可以通过Call/CallEx方法调用这个Dispatch的方法
    /// <remarks>
    /// 注意：因为IPC通信是很耗时的，且可能造成死锁，所以请不要在IPC调用的方法里做很耗时的操作
    /// </remarks>
    /// </summary>
    property Dispatch: IDispatch read GetDispatch write SetDispatch;
    /// <summary>
    /// 一个扩展字段，用户可以用它存储任何数据
    /// </summary>
    property Tag: Pointer read GetTag write SetTag;
    /// <summary>
    /// 最近一次错误信息
    /// </summary>
    property LastError: WideString read GetLastError;
  end;

  /// <summary>
  /// IPC客户端接口，该接口封装了IPC客户端的相关功能
  /// </summary>
  /// <example>
  /// <code>
  ///   LClient := CreateIPCClient("AIPCSessionName");
  ///   LClient.OnMessage := DoClientMessageMethod;
  ///   LClient.Open;
  ///   if not LClient.Send("Hello, I'm client.") then
  ///     LogWarning("发送数据失败");
  /// </code>
  /// </example>
  IIPCClient = interface
  ['{D7899668-228D-4B9E-8F7B-842908D9B336}']
    function GetID: Cardinal;
    function GetServerID: Cardinal;
    function GetActive: Boolean;
    function GetReciveMessageInThread: Boolean;
    function GetReciveMessageToQueue: Boolean;
    function GetSessionName: WideString;
    function GetSessionHandle: Cardinal;
    function GetReciveQueue: PIIPCMessageQueue;
    function GetOnMessage: TIPCClientMessageEvent;
    function GetDispatch: IDispatch;
    function GetTag: Pointer;
    function GetLastError: WideString;
    procedure SetActive(const Value: Boolean);
    procedure SetReciveMessageInThread(const Value: Boolean);
    procedure SetReciveMessageToQueue(const Value: Boolean);
    procedure SetSessionName(const Value: WideString);
    procedure SetOnMessage(const Value: TIPCClientMessageEvent);
    procedure SetDispatch(const Value: IDispatch);
    procedure SetTag(const Value: Pointer);
    
    function Implementor: Pointer;

    /// <summary>
    /// 检查ASessionName会话是否存在(创建)
    /// </summary>
    /// <param name="ASessionName">待检查的会话名称</param>
    /// <returns></returns>
    function IsExist(const ASessionName: WideString): Boolean;
    /// <summary>
    /// 检查是否与服务端连接
    /// </summary>
    function IsConnect: Boolean;
    /// <summary>
    /// IPC客户端是否已经打开
    /// </summary>
    function IsOpened: Boolean;
    /// <summary>
    /// 打开一个IPC会话，连接到该会话的服务端，如果未找到则返回False。在调用该
    /// 方法之前需要先设置SessionName属性。
    /// </summary>
    /// <param name="AConnectServer">是否连接到服务端，如果为True是，当未找到服务端时返回Fasle</param>
    /// <param name="ATimeOut">连接服务端的超时时间</param>
    /// <returns>打开是否成功</returns>
    function Open(const bFailIfServerNotExist: Boolean = True; const ATimeOut: Cardinal = IPC_TIMEOUT_OPENCLOSE): Boolean; overload;
    /// <summary>
    /// 打开一个IPC会话，连接到该会话的服务端，如果未找到则返回False。
    /// </summary>
    /// <param name="ASessionName">待打开的会话名称</param>
    /// <param name="AConnectServer">是否连接到服务端，如果为True是，当未找到服务端时返回Fasle</param>
    /// <param name="ATimeOut">连接服务端的超时时间</param>
    /// <returns>打开是否成功</returns>
    function Open(const ASessionName: WideString;  const bFailIfServerNotExist: Boolean = True;
      const ATimeOut: Cardinal = IPC_TIMEOUT_OPENCLOSE): Boolean; overload;
    /// <summary>
    /// 关闭一个IPC会话，该方法会断开与IPC服务端的连接
    /// </summary>
    procedure Close;
    /// <summary>
    /// 检查IPCServer有没有实现指定的方法
    /// </summary>
    /// <param name="AMethodName">待检查的方法名</param>
    /// <returns></returns>
    function MethodExist(const AMethodName: WideString): Boolean;
    /// <summary>
    /// 调用连接的IPCServer绑定的Dispatch对象的方法
    /// </summary>
    /// <param name="AMethodName">方法名</param>
    /// <param name="AParams">调用参数(注：参数仅支持IIPCMessage支持的类型)</param>
    /// <param name="ATimeOut">调用超时时间</param>
    /// <returns>服务端方法返回的结果</returns>
    function TryCall(const AMethodName: WideString; const AParams: array of OleVariant;
      out AResult: IIPCMessage; const ATimeOut: Cardinal): Boolean;
    function TryCallEx(const AMethodName: WideString; const AParams: array of IIPCMessage;
      out AResult: IIPCMessage; const ATimeOut: Cardinal): Boolean;
    function Call(const AMethodName: WideString; const AParams: array of OleVariant; const ATimeOut: Cardinal = IPC_TIMEOUT): IIPCMessage;
    function CallEx(const AMethodName: WideString; const AParams: array of IIPCMessage; const ATimeOut: Cardinal = IPC_TIMEOUT): IIPCMessage;  
    /// <summary>
    /// 向IPC服务端发送数据，以下有一系列的不同数据类型的重载函数
    /// </summary>
    /// <param name="AData">待发送的数据</param>
    /// <param name="ATimeOut">等待服务端反馈的最大时间(超时时间)</param>
    /// <returns>
    ///  处理结果：
    /// <list type="Boolean">
    /// <item>
    /// <term>False</term>
    /// <description>发送失败</description>
    /// </item>
    /// <item>
    /// <term>True</term>
    /// <description>发送成功</description>
    /// </item>
    /// </list>
    /// </returns>
    function Send(const AData: IIPCMessage; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AData: Pointer; const ADataLen: Cardinal; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AData: WideString; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AData: Int64; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AData: Boolean; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AData: Double; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function SendC(const AData: Currency; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean;
    function SendDT(const AData: TDateTime; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean;
    function SendFile(const AFileName: WideString; ATimeOut: Cardinal = IPC_TIMEOUT): Boolean;
    /// <summary>
    /// IPC客户端打开后创建的客户端ID
    /// </summary>
    property ID: Cardinal read GetID;
    /// <summary>
    /// IPC会话名称(频道)，客户端和服务端通过这个名称来区分是否连接配对
    /// </summary>
    property SessionName: WideString read GetSessionName write SetSessionName;
    /// <summary>
    /// IPC会话句柄，客户端和服务端通过这个句柄来进行连接配对
    /// </summary>
    property SessionHandle: Cardinal read GetSessionHandle;
    /// <summary>
    /// 获取/设置当前IPC会话状态(打开/关闭，相当于调用Open/Close方法)
    /// </summary>
    property Active: Boolean read GetActive write SetActive;
    /// <summary>
    /// 在OnMessage事件中接收数据状态的处理是否放在一个独立线程中
    /// </summary>
    /// <list type="Boolean">
    /// <item>
    /// <term>False(默认)</term>
    /// <description>在OnMessage事件在主线程中处理接收的数据</description>
    /// </item>
    /// <item>
    /// <term>True</term>
    /// <description>OnMessage事件在一个独立线程中处理接收的数据</description>
    /// </item>
    /// </list>
    property ReciveMessageInThread: Boolean read GetReciveMessageInThread write SetReciveMessageInThread;
    /// <summary>
    /// 是否将接受到的消息放入消息队列，如果为True时，OnMessage事件将接受不到IsReciveMessage消息
    /// </summary>
    property ReciveMessageToQueue: Boolean read GetReciveMessageToQueue write SetReciveMessageToQueue;
    /// <summary>
    /// 连接到的IPC服务端的服务ID
    /// </summary>
    property ServerID: Cardinal read GetServerID;
    /// <summary>
    /// 消息队列，如果ReciveMessageInQueue为True，则接收到的消息将放入该队列中，而不是调用OnMessage事件
    /// </summary>
    property ReciveQueue: PIIPCMessageQueue read GetReciveQueue;
    /// <summary>
    /// IPC客户端状态与接收数据的事件处理器
    /// </summary>
    property OnMessage: TIPCClientMessageEvent read GetOnMessage write SetOnMessage;
    /// <summary>
    /// 绑定的IDispatch对象，IPC另一端可以通过Call/CallEx方法调用这个Dispatch的方法
    /// <remarks>
    /// 注意：因为IPC通信是很耗时的，且可能造成死锁，所以请不要在IPC调用的方法里做很耗时的操作
    /// </remarks>
    /// </summary>
    property Dispatch: IDispatch read GetDispatch write SetDispatch;
    /// <summary>
    /// 一个扩展字段，用户可以用它存储任何数据
    /// </summary>
    property Tag: Pointer read GetTag write SetTag;
    /// <summary>
    /// 最近一次错误信息
    /// </summary>
    property LastError: WideString read GetLastError;
  end;

function CreateIPCServer: IIPCServer; overload;
function CreateIPCServer(const ASessionName: WideString): IIPCServer; overload;
function CreateIPCClient: IIPCClient; overload;
function CreateIPCClient(const ASessionName: WideString): IIPCClient; overload;
function CreateIPCMessage(const ADataType: TIPCMessageDataType = mdtUnknown): IIPCMessage;
function CreateIPCMessageReadOnly(const AData: TMessageData;
  const ADataSize: Cardinal; const ADataType: TIPCMessageDataType): IIPCMessage;
  
implementation

uses
  SYIPCImportDef;

function CreateIPCMessage(const ADataType: TIPCMessageDataType): IIPCMessage;
type
  TCreateIPCMessage = function (const ADataType: TIPCMessageDataType): IIPCMessage;
begin
  Result := TCreateIPCMessage(IPCAPI.Funcs[FuncIdx_CreateIPCMessage])(ADataType);
end;

function CreateIPCMessageReadOnly(const AData: TMessageData;
  const ADataSize: Cardinal; const ADataType: TIPCMessageDataType): IIPCMessage;
type
  TCreateIPCMessageReadOnly = function (const AData: TMessageData;
    const ADataSize: Cardinal; const ADataType: TIPCMessageDataType): IIPCMessage;
begin
  Result := TCreateIPCMessageReadOnly(IPCAPI.Funcs[FuncIdx_CreateIPCMessageReadOnly])
    (AData, ADataSize, ADataType);
end;

function CreateIPCServer: IIPCServer;
type
  TCreateIPCServer = function : IIPCServer;
begin
  Result := TCreateIPCServer(IPCAPI.Funcs[FuncIdx_CreateIPCServer]);
end;

function CreateIPCServer(const ASessionName: WideString): IIPCServer;
begin
  Result := CreateIPCServer;
  Result.SessionName := ASessionName;
end;

function CreateIPCClient: IIPCClient;
type
  TCreateIPCClient = function : IIPCClient;
begin
  Result := TCreateIPCClient(IPCAPI.Funcs[FuncIdx_CreateIPCClient]);
end;

function CreateIPCClient(const ASessionName: WideString): IIPCClient;
begin
  Result := CreateIPCClient;
  Result.SessionName := ASessionName;
end;

end.
