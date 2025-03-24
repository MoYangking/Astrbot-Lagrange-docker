using Lagrange.Core.Common;
using Lagrange.Core.Internal.Event;
using Lagrange.Core.Internal.Event.Message;
using Lagrange.Core.Internal.Packets.Service.Oidb;
using Lagrange.Core.Internal.Packets.Service.Oidb.Common;
using Lagrange.Core.Utility.Extension;
using ProtoBuf;

namespace Lagrange.Core.Internal.Service.Message;

[EventSubscribe(typeof(ImageDownloadEvent))]
[Service("OidbSvcTrpcTcp.0x11c5_200")]
internal class ImageDownloadService : BaseService<ImageDownloadEvent>
{
    protected override bool Build(ImageDownloadEvent input, BotKeystore keystore, BotAppInfo appInfo,
        BotDeviceInfo device, out Span<byte> output, out List<Memory<byte>>? extraPackets)
    {
        var packet = new OidbSvcTrpcTcpBase<NTV2RichMediaReq>(new NTV2RichMediaReq
        {
            ReqHead = new MultiMediaReqHead
            {
                Common = new CommonHead
                {
                    RequestId = 1,
                    Command = 200
                },
                Scene = new SceneInfo
                {
                    RequestType = 2,
                    BusinessType = 1,
                    SceneType = 1,
                    C2C = new C2CUserInfo
                    {
                        AccountType = 2,
                        TargetUid = input.SelfUid
                    }
                },
                Client = new ClientMeta { AgentType = 2 }
            },
            Download = new DownloadReq
            {
                Node = input.Node,
                Download = new DownloadExt
                {
                    Video = new VideoDownloadExt
                    {
                        BusiType = 0,
                        SceneType = 0
                    }
                }
            }
        }, 0x11c5, 200, false, true);
        
        output = packet.Serialize();
        extraPackets = null;
        
        return true;
    }

    protected override bool Parse(Span<byte> input, BotKeystore keystore, BotAppInfo appInfo, BotDeviceInfo device, 
        out ImageDownloadEvent output, out List<ProtocolEvent>? extraEvents)
    {
        var payload = Serializer.Deserialize<OidbSvcTrpcTcpBase<NTV2RichMediaResp>>(input);
        var body = payload.Body.Download;
        string url = $"https://{body.Info.Domain}{body.Info.UrlPath}{body.RKeyParam}";
        
        output = ImageDownloadEvent.Result((int)payload.ErrorCode, url);
        extraEvents = null;
        return true;
    }
}