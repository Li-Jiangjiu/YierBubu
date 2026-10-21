using System.Globalization;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
namespace YierBubu.Windows;

/// Geometry is in the approved 1536x1024 illustration, shared with the core model.
public sealed class SceneRenderer
{
    private readonly Assets assets;
    private readonly ImageSource leftPaw,rightPaw,mousePaw;
    private static readonly Color Ink=Color.FromRgb(74,38,26),Accent=Color.FromRgb(255,168,102),Cream=Color.FromRgb(255,246,230);
    private static readonly Rect Canvas=new(0,0,1536,1024);
    private static readonly Geometry MouseSilhouette=Geometry.Parse("M291,528 C306,502 337,492 362,501 C409,497 435,522 424,547 C425,572 411,588 385,591 C342,609 270,588 280,557 C274,547 284,534 291,528 Z");
    private static readonly Geometry LeftSilhouette=Geometry.Parse("M776,648 C784,626 815,607 838,616 C878,613 904,640 901,666 C904,687 897,699 874,701 C832,711 777,688 776,673 C766,666 767,658 776,648 Z");
    private static readonly Geometry RightSilhouette=Geometry.Parse("M1056,726 C1066,700 1092,684 1122,692 C1156,690 1188,708 1192,736 C1212,766 1200,776 1180,780 C1137,800 1084,780 1058,755 C1046,747 1046,737 1056,726 Z");
    private static readonly Geometry KeyboardArea=Geometry.Parse("M446,739 L612,626 L1366,851 C1383,894 1334,966 1308,995 L1110,995 L447,796 Z");
    private static readonly Geometry MouseOutline=Geometry.Parse("M197,635 C194,590 328,528 387,558 C441,576 403,620 376,640 C296,702 190,688 197,635 Z");
    public SceneRenderer(Assets assets)
    {
        this.assets=assets;
        leftPaw=Crop(assets.Paws,new(755,567,158,114));rightPaw=Crop(assets.Paws,new(1083,639,175,116));mousePaw=Crop(assets.Paws,new(268,461,165,125));
    }
    private static ImageSource Crop(BitmapSource image,Int32Rect rect){var b=new CroppedBitmap(image,rect);b.Freeze();return b;}
    private static Point P(Point2 point)=>new(point.X,point.Y);
    private static SolidColorBrush Brush(Color color,double opacity=1){var b=new SolidColorBrush(color){Opacity=opacity};b.Freeze();return b;}
    private static Pen Pen(Color color,double width,double opacity=1)=>new(Brush(color,opacity),width){StartLineCap=PenLineCap.Round,EndLineCap=PenLineCap.Round,LineJoin=PenLineJoin.Round};
    private static Geometry Expanded(Geometry path)
    {
        var b=path.Bounds;var clone=path.Clone();clone.Transform=new ScaleTransform(1+12/b.Width,1+12/b.Height,b.X+b.Width/2,b.Y+b.Height/2);return clone;
    }
    private void ImageClipped(DrawingContext dc,Geometry clip,ImageSource image){dc.PushClip(clip);dc.DrawImage(image,Canvas);dc.Pop();}
    public void Draw(DrawingContext dc,InteractionSnapshot state,ScenePaws poses,bool blinking)
    {
        var erasures=new GeometryGroup{FillRule=FillRule.Nonzero};
        if(poses.Mouse!=null)erasures.Children.Add(Expanded(MouseSilhouette));
        if(poses.Left!=null)erasures.Children.Add(Expanded(LeftSilhouette));
        if(poses.Right!=null)erasures.Children.Add(Expanded(RightSilhouette));
        if(erasures.Children.Count>0){var remaining=Geometry.Combine(new RectangleGeometry(Canvas),erasures,GeometryCombineMode.Exclude,null);ImageClipped(dc,remaining,assets.Scene);ImageClipped(dc,erasures,assets.Cleanplate);}
        else dc.DrawImage(assets.Scene,Canvas);
        if(blinking||state.Resting){foreach(var rect in new Rect[]{new(310,307,73,66),new(492,363,88,86),new(841,437,85,83),new(1040,504,94,94)})ImageClipped(dc,new EllipseGeometry(rect),assets.Cleanplate);}
        ImageClipped(dc,KeyboardArea,assets.Cleanplate);
        foreach(var key in SceneLayout.Keys){bool active=state.Keys.Contains(key.Label);var selected=key.LeftPaw?state.LeftKey:state.RightKey;var hand=key.LeftPaw?poses.Left:poses.Right;bool arrived=hand!=null&&Math.Sqrt(Math.Pow(hand.Contact.X-key.Contact.X,2)+Math.Pow(hand.Contact.Y-key.Contact.Y,2))<8;DrawKey(dc,key,active,active&&(selected!=key.Label||arrived));}
        DrawMouse(dc,state);
        if(poses.Mouse is {} mouse)DrawPaw(dc,mouse,true);
        if(poses.Left is {} left)DrawPaw(dc,left,true);else ImageClipped(dc,LeftSilhouette,assets.Scene);
        if(poses.Right is {} right)DrawPaw(dc,right,false);else ImageClipped(dc,RightSilhouette,assets.Scene);
    }
    private static Geometry Rounded(IReadOnlyList<Point2> points,double radius)
    {
        var path=new StreamGeometry();using(var c=path.Open()){
            for(int i=0;i<points.Count;i++){
                var point=points[i];var prev=points[(i+points.Count-1)%points.Count];var next=points[(i+1)%points.Count];
                Point Inset(Point2 other){double length=Math.Sqrt(Math.Pow(other.X-point.X,2)+Math.Pow(other.Y-point.Y,2));double t=Math.Min(radius/length,0.3);return new(point.X+(other.X-point.X)*t,point.Y+(other.Y-point.Y)*t);}
                var start=Inset(prev);var end=Inset(next);if(i==0)c.BeginFigure(start,true,true);else c.LineTo(start,true,false);c.BezierTo(P(point),P(point),end,true,false);
            }
        }path.Freeze();return path;
    }
    private static Brush Gradient(Color top,Color bottom)=>new LinearGradientBrush(top,bottom,new Point(0,0),new Point(0,1));
    private static void DrawKey(DrawingContext dc,KeyGeometry key,bool active,bool depressed)
    {
        var top=key.SurfaceCenter(depressed);var corners=key.SurfaceCorners(depressed);var baseCorners=key.Corners(8);
        dc.DrawGeometry(Brush(Ink,depressed?0.13:0.20),null,Rounded(baseCorners.Select(p=>new Point2(p.X+1,p.Y+(depressed?2:5))).ToArray(),17));
        bool peach="10zm".Contains(key.Label);
        var side=active?Color.FromRgb(214,117,64):peach?Color.FromRgb(207,145,110):Color.FromRgb(207,168,138);
        dc.DrawGeometry(Brush(side),Pen(Ink,3.5,0.65),Rounded(baseCorners,17));
        var light=active?Color.FromRgb(255,201,145):peach?Color.FromRgb(255,222,194):Color.FromRgb(255,251,242);
        var shade=active?Accent:peach?Color.FromRgb(252,194,161):Cream;
        dc.DrawGeometry(Gradient(light,shade),Pen(Ink,3.2,0.62),Rounded(corners,17));
        var inset=corners.Select(p=>new Point2(top.X+(p.X-top.X)*0.88,top.Y+(p.Y-top.Y)*0.8)).ToArray();
        dc.DrawGeometry(null,Pen(Colors.White,2.5,0.58),Rounded(inset,13));
        dc.PushTransform(new TranslateTransform(top.X,top.Y));dc.PushTransform(new RotateTransform(Math.Atan2(key.Across.Y,key.Across.X)*180/Math.PI));
        var text=new FormattedText(key.Label.ToString(),CultureInfo.InvariantCulture,FlowDirection.LeftToRight,new Typeface(new FontFamily("Arial Rounded MT Bold, Segoe UI"),FontStyles.Normal,FontWeights.Bold,FontStretches.Normal),27,Brush(Ink),1);
        dc.DrawText(text,new Point(-text.Width/2,-text.Height/2));dc.Pop();dc.Pop();
    }
    private static void DrawMouse(DrawingContext dc,InteractionSnapshot state)
    {
        dc.PushClip(MouseOutline);
        foreach(var b in new[]{MouseButton.Left,MouseButton.Right})if(state.Buttons.Contains(b))dc.DrawGeometry(Brush(Accent,0.7),Pen(Ink,3,0.5),Rounded(SceneLayout.MouseRegion(b),10));
        dc.Pop();bool scroll=state.ScrollX!=0||state.ScrollY!=0;
        if(state.Buttons.Contains(MouseButton.Middle)||scroll){var wheel=Geometry.Parse("M256,617 C248,606 282,574 296,580 C301,580 305,583 303,588 C301,599 276,625 265,625 Z");dc.DrawGeometry(Brush(Accent),Pen(Ink,3),wheel);
            if(state.ScrollY!=0)Arrow(dc,new(237,593),state.ScrollY>0?16:-16,state.ScrollY>0?-17:17);
            if(state.ScrollX!=0)Arrow(dc,new(310,640),state.ScrollX>0?-18:18,state.ScrollX>0?-8:8);
        }
    }
    private static void Arrow(DrawingContext dc,Point2 center,double dx,double dy)
    {
        var end=new Point(center.X+dx,center.Y+dy);var pen=Pen(Ink,4);
        dc.DrawLine(pen,P(center),end);dc.DrawLine(pen,new(end.X-dx*0.55-dy*0.35,end.Y-dy*0.55+dx*0.35),end);dc.DrawLine(pen,end,new(end.X-dx*0.55+dy*0.35,end.Y-dy*0.55-dx*0.35));
    }
    private void DrawPaw(DrawingContext dc,PawPose pose,bool left)
    {
        var center=pose.Center;var shoulder=pose.Shoulder;var elbow=pose.Elbow;
        double dx=center.X-shoulder.X,dy=center.Y-shoulder.Y,length=Math.Max(1,Math.Sqrt(dx*dx+dy*dy)),nx=-dy/length,ny=dx/length;
        var arm=new StreamGeometry();using(var c=arm.Open()){
            c.BeginFigure(new(shoulder.X+nx*36,shoulder.Y+ny*36),true,false);
            c.BezierTo(new(elbow.X+nx*32,elbow.Y+ny*32),new(center.X-dx*0.14+nx*27,center.Y-dy*0.14+ny*27),new(center.X+nx*25,center.Y+ny*25),true,false);
            c.BezierTo(new(center.X+dx*0.08,center.Y+dy*0.08),new(center.X+dx*0.08,center.Y+dy*0.08),new(center.X-nx*25,center.Y-ny*25),true,false);
            c.BezierTo(new(center.X-dx*0.14-nx*27,center.Y-dy*0.14-ny*27),new(elbow.X-nx*32,elbow.Y-ny*32),new(shoulder.X-nx*36,shoulder.Y-ny*36),true,false);
        }
        dc.DrawGeometry(Gradient(pose.IsMouse?Color.FromRgb(247,194,161):Colors.White,pose.IsMouse?Color.FromRgb(232,168,133):Color.FromRgb(255,245,237)),Pen(Ink,6),arm);
        dc.PushTransform(new TranslateTransform(center.X,center.Y));dc.PushTransform(new RotateTransform(pose.Angle*180/Math.PI));dc.DrawImage(pose.IsMouse?mousePaw:left?leftPaw:rightPaw,new Rect(-72,-47,144,94));dc.Pop();dc.Pop();
    }
}
