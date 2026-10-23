import AppKit
import BubuCore

/// All animation coordinates share the approved 1536×1024 illustration's projection.
@MainActor
struct SceneRenderer {
    private let ink = NSColor(calibratedRed:0.29,green:0.15,blue:0.10,alpha:1)
    private let cream = NSColor(calibratedRed:1,green:0.965,blue:0.90,alpha:1)
    private let accent = NSColor(calibratedRed:1,green:0.66,blue:0.40,alpha:1)
    private let canvas = NSRect(x:0,y:0,width:1536,height:1024)

    func draw(scene: NSImage?, cleanplate: NSImage?, paws:NSImage?, state: InteractionSnapshot, blinking: Bool, poses:ScenePaws? = nil) {
        guard let scene, let cleanplate,let paws else {
            ("动画资源缺失 · 请重新安装" as NSString).draw(at:NSPoint(x:400,y:500),
                withAttributes:[.font:NSFont.systemFont(ofSize:45),.foregroundColor:ink])
            return
        }
        drawImage(scene)
        // Erase only moving paw silhouettes, not rectangular surroundings.
        // Idle retains the exact approved paw/background pixels.
        let poses=poses ?? ScenePaws(state:state)
        if poses.mouse != nil { erasePaw(mousePaw(),with:cleanplate) }
        if poses.left != nil { erasePaw(leftPaw(),with:cleanplate) }
        if poses.right != nil { erasePaw(rightPaw(),with:cleanplate) }
        if blinking || state.resting {
            for rect in [NSRect(x:310,y:307,width:73,height:66),NSRect(x:492,y:363,width:88,height:86),
                         NSRect(x:841,y:437,width:85,height:83),NSRect(x:1040,y:504,width:94,height:94)] {
                clipped(NSBezierPath(ovalIn:rect)) { drawImage(cleanplate, operation:.sourceAtop) }
            }
        }
        // Cover the old generated caps with a clean top plate before drawing precise geometry.
        let keyArea=NSBezierPath()
        keyArea.move(to:p(446,739));keyArea.line(to:p(612,626));keyArea.line(to:p(1366,851))
        keyArea.curve(to:p(1308,995),controlPoint1:p(1383,894),controlPoint2:p(1334,966))
        keyArea.line(to:p(1110,995));keyArea.line(to:p(447,796));keyArea.close()
        clipped(keyArea) { drawImage(cleanplate, operation:.sourceAtop) }
        for key in CompactSceneLayout.keys {
            let active=state.keys.contains(key.code)
            let selected=key.leftPaw ? state.leftKey : state.rightKey
            let hand=key.leftPaw ? poses.left : poses.right
            let arrived=hand.map { hypot($0.contact.x-key.contact.x,$0.contact.y-key.contact.y)<8 } ?? false
            drawKey(key,active:active,depressed:active && (selected != key.code || arrived))
        }
        drawMouse(state)
        if let pose=poses.mouse { drawPosedPaw(paws,pose:pose,left:true) }
        if let pose=poses.left { drawPosedPaw(paws,pose:pose,left:true) }
        else { clipped(leftPaw()) { drawImage(scene) } }
        if let pose=poses.right { drawPosedPaw(paws,pose:pose,left:false) }
        else { clipped(rightPaw()) { drawImage(scene) } }
    }

    private func drawKey(_ key:CompactKey, active:Bool,depressed:Bool) {
        let top=key.surfaceCenter(pressed:depressed)
        let topCorners=key.surfaceCorners(pressed:depressed).map { p($0.x,$0.y) }
        let baseCorners=key.corners.map { p($0.x,$0.y+8) }
        let shadow=roundedPolygon(baseCorners.map { p($0.x+1,$0.y+(depressed ? 2 : 5)) },radius:17)
        ink.withAlphaComponent(depressed ? 0.13 : 0.20).setFill();shadow.fill()
        let base=roundedPolygon(baseCorners,radius:17)
        let peach=["1","0","z","m"].contains(key.label)
        let side=active ? NSColor(calibratedRed:0.84,green:0.46,blue:0.25,alpha:1)
            : NSColor(calibratedRed:0.81,green:peach ? 0.57 : 0.66,blue:peach ? 0.43 : 0.54,alpha:1)
        side.setFill();base.fill();ink.withAlphaComponent(0.65).setStroke();base.lineWidth=3.5;base.stroke()
        let path=roundedPolygon(topCorners,radius:17)
        let light=active ? NSColor(calibratedRed:1,green:0.79,blue:0.57,alpha:1)
            : NSColor(calibratedRed:1,green:peach ? 0.87 : 0.985,blue:peach ? 0.76 : 0.95,alpha:1)
        let shade=active ? accent : peach ? NSColor(calibratedRed:0.99,green:0.76,blue:0.63,alpha:1) : cream
        NSGradient(starting:light,ending:shade)?.draw(in:path,angle:90)
        ink.withAlphaComponent(0.62).setStroke();path.lineWidth=3.2;path.stroke()
        let inset=topCorners.map { p(top.x+($0.x-top.x)*0.88,top.y+($0.y-top.y)*0.80) }
        NSColor.white.withAlphaComponent(0.58).setStroke()
        let bevel=roundedPolygon(inset,radius:13);bevel.lineWidth=2.5;bevel.stroke()
        guard let context=NSGraphicsContext.current?.cgContext else { return }
        context.saveGState();context.translateBy(x:top.x,y:top.y)
        context.rotate(by:atan2(key.across.y,key.across.x))
        let font=NSFont(name:"ArialRoundedMTBold",size:27) ?? NSFont.systemFont(ofSize:27,weight:.bold)
        let attrs:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:ink]
        let label=key.label as NSString,size=label.size(withAttributes:attrs)
        label.draw(at:p(-size.width/2,-size.height/2),withAttributes:attrs)
        context.restoreGState()
    }

    private func drawMouse(_ state:InteractionSnapshot) {
        // Nose faces lower-left, away from BuBu; character-left is the lower-right half.
        let left=roundedPolygon(MouseSceneLayout.region(for:.left).map { p($0.x,$0.y) },radius:10)
        let right=roundedPolygon(MouseSceneLayout.region(for:.right).map { p($0.x,$0.y) },radius:10)
        let mouse=NSBezierPath()
        mouse.move(to:p(197,635));mouse.curve(to:p(387,558),controlPoint1:p(194,590),controlPoint2:p(328,528))
        mouse.curve(to:p(376,640),controlPoint1:p(441,576),controlPoint2:p(403,620))
        mouse.curve(to:p(197,635),controlPoint1:p(296,702),controlPoint2:p(190,688));mouse.close()
        clipped(mouse) {
            for (button,path) in [(MouseButton.left,left),(.right,right)] where state.buttons.contains(button) {
                accent.withAlphaComponent(0.70).setFill();path.fill()
                ink.withAlphaComponent(0.5).setStroke();path.lineWidth=3;path.stroke()
            }
        }
        let scrolling=state.scrollX != 0 || state.scrollY != 0
        if state.buttons.contains(.middle) || scrolling {
            let wheel=NSBezierPath()
            wheel.move(to:p(256,617));wheel.curve(to:p(296,580),controlPoint1:p(248,606),controlPoint2:p(282,574))
            wheel.curve(to:p(303,588),controlPoint1:p(301,580),controlPoint2:p(305,583))
            wheel.curve(to:p(265,625),controlPoint1:p(301,599),controlPoint2:p(276,625));wheel.close()
            accent.setFill();wheel.fill();ink.setStroke();wheel.lineWidth=3;wheel.stroke()
            if scrolling {
                // Directional chevrons beside the wheel, in the device plane, never L/R labels.
                if state.scrollY != 0 {
                    arrow(center:p(237,593),dx:state.scrollY > 0 ? 16 : -16,dy:state.scrollY > 0 ? -17 : 17)
                }
                if state.scrollX != 0 {
                    arrow(center:p(310,640),dx:state.scrollX > 0 ? -18 : 18,dy:state.scrollX > 0 ? -8 : 8)
                }
            }
        }
    }
    private func arrow(center:NSPoint,dx:CGFloat,dy:CGFloat) {
        let path=NSBezierPath();let end=p(center.x+dx,center.y+dy)
        path.move(to:center);path.line(to:end)
        path.move(to:p(end.x-dx*0.55-dy*0.35,end.y-dy*0.55+dx*0.35));path.line(to:end)
        path.line(to:p(end.x-dx*0.55+dy*0.35,end.y-dy*0.55-dx*0.35))
        ink.setStroke();path.lineWidth=4;path.lineCapStyle = .round;path.lineJoinStyle = .round;path.stroke()
    }
    private func drawPosedPaw(_ image:NSImage,pose:PawPose,left:Bool) {
        let center=pose.center
        let shoulder=pose.shoulder
        let dx=center.x-shoulder.x,dy=center.y-shoulder.y,length=max(1,hypot(dx,dy))
        let nx = -dy/length,ny=dx/length
        let elbow=pose.elbow
        let arm=NSBezierPath()
        arm.move(to:p(shoulder.x+nx*36,shoulder.y+ny*36))
        arm.curve(to:p(center.x+nx*25,center.y+ny*25),
                  controlPoint1:p(elbow.x+nx*32,elbow.y+ny*32),
                  controlPoint2:p(center.x-dx*0.14+nx*27,center.y-dy*0.14+ny*27))
        arm.curve(to:p(center.x-nx*25,center.y-ny*25),
                  controlPoint1:p(center.x+dx*0.08,center.y+dy*0.08),
                  controlPoint2:p(center.x+dx*0.08,center.y+dy*0.08))
        arm.curve(to:p(shoulder.x-nx*36,shoulder.y-ny*36),
                  controlPoint1:p(center.x-dx*0.14-nx*27,center.y-dy*0.14-ny*27),
                  controlPoint2:p(elbow.x-nx*32,elbow.y-ny*32))
        // Fill into the torso, but do not stroke a cut line across the shoulder attachment.
        let outline=arm.copy() as! NSBezierPath
        arm.close()
        let light=pose.mouse ? NSColor(calibratedRed:0.97,green:0.76,blue:0.63,alpha:1) : NSColor.white
        let shade=pose.mouse ? NSColor(calibratedRed:0.91,green:0.66,blue:0.52,alpha:1) : NSColor(calibratedRed:1,green:0.96,blue:0.93,alpha:1)
        NSGradient(starting:light,ending:shade)?.draw(in:arm,angle:90)
        ink.setStroke();outline.lineWidth=6;outline.lineJoinStyle = .round;outline.lineCapStyle = .round;outline.stroke()
        guard let context=NSGraphicsContext.current?.cgContext else { return }
        context.saveGState();context.translateBy(x:center.x,y:center.y);context.rotate(by:pose.angle)
        let source=pose.mouse ? NSRect(x:268,y:461,width:165,height:125)
            : left ? NSRect(x:755,y:567,width:158,height:114) : NSRect(x:1083,y:639,width:175,height:116)
        drawPaw(image,source:source,target:NSRect(x:-72,y:-47,width:144,height:94),dx:0,dy:0)
        context.restoreGState()
    }
    private func drawPaw(_ image:NSImage,source:NSRect,target:NSRect,dx:CGFloat,dy:CGFloat) {
        guard let context=NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        let sx=target.width/source.width,sy=target.height/source.height
        context.translateBy(x:target.minX+dx-source.minX*sx,y:target.minY+dy-source.minY*sy)
        context.scaleBy(x:sx,y:sy)
        clipped(NSBezierPath(rect:source)) { drawImage(image) }
        context.restoreGState()
    }
    private func erasePaw(_ path:NSBezierPath,with image:NSImage) {
        expandedClip(path,width:12) { drawImage(image,operation:.copy) }
    }
    private func expandedClip(_ path:NSBezierPath,width:CGFloat,draw:()->Void) {
        guard let context=NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        let bounds=path.bounds
        let sx=1+width/bounds.width,sy=1+width/bounds.height
        if #available(macOS 14, *) {
            var transform=CGAffineTransform(a:sx,b:0,c:0,d:sy,
                tx:bounds.midX*(1-sx),ty:bounds.midY*(1-sy))
            guard let expanded=path.cgPath.copy(using:&transform) else {
                context.restoreGState()
                return
            }
            context.addPath(expanded)
            context.clip()
        } else {
            let transform=NSAffineTransform()
            transform.transformStruct=NSAffineTransformStruct(m11:sx,m12:0,m21:0,m22:sy,
                tX:bounds.midX*(1-sx),tY:bounds.midY*(1-sy))
            let expanded=path.copy() as! NSBezierPath
            expanded.transform(using:transform as AffineTransform)
            expanded.addClip()
        }
        draw()
        context.restoreGState()
    }
    private func mousePaw() -> NSBezierPath {
        let path=NSBezierPath()
        path.move(to:p(291,528));path.curve(to:p(362,501),controlPoint1:p(306,502),controlPoint2:p(337,492))
        path.curve(to:p(424,547),controlPoint1:p(409,497),controlPoint2:p(435,522))
        path.curve(to:p(385,591),controlPoint1:p(425,572),controlPoint2:p(411,588))
        path.curve(to:p(280,557),controlPoint1:p(342,609),controlPoint2:p(270,588))
        path.curve(to:p(291,528),controlPoint1:p(274,547),controlPoint2:p(284,534));path.close();return path
    }
    private func leftPaw() -> NSBezierPath {
        let path=NSBezierPath();path.move(to:p(776,648))
        path.curve(to:p(838,616),controlPoint1:p(784,626),controlPoint2:p(815,607))
        path.curve(to:p(901,666),controlPoint1:p(878,613),controlPoint2:p(904,640))
        path.curve(to:p(874,701),controlPoint1:p(904,687),controlPoint2:p(897,699))
        path.curve(to:p(776,673),controlPoint1:p(832,711),controlPoint2:p(777,688))
        path.curve(to:p(776,648),controlPoint1:p(766,666),controlPoint2:p(767,658));path.close();return path
    }
    private func rightPaw() -> NSBezierPath {
        let path=NSBezierPath();path.move(to:p(1056,726))
        path.curve(to:p(1122,692),controlPoint1:p(1066,700),controlPoint2:p(1092,684))
        path.curve(to:p(1192,736),controlPoint1:p(1156,690),controlPoint2:p(1188,708))
        path.curve(to:p(1180,780),controlPoint1:p(1212,766),controlPoint2:p(1200,776))
        path.curve(to:p(1058,755),controlPoint1:p(1137,800),controlPoint2:p(1084,780))
        path.curve(to:p(1056,726),controlPoint1:p(1046,747),controlPoint2:p(1046,737));path.close();return path
    }
    private func drawImage(_ image:NSImage, operation:NSCompositingOperation = .sourceOver) {
        image.draw(in:canvas,from:.zero,operation:operation,fraction:1,respectFlipped:true,
                   hints:[.interpolation:NSImageInterpolation.high])
    }
    private func clipped(_ path:NSBezierPath,draw:()->Void) {
        NSGraphicsContext.saveGraphicsState();path.addClip();draw();NSGraphicsContext.restoreGraphicsState()
    }
    private func roundedPolygon(_ points:[NSPoint],radius:CGFloat) -> NSBezierPath {
        let path=NSBezierPath()
        for i in points.indices {
            let prev=points[(i+points.count-1)%points.count],point=points[i],next=points[(i+1)%points.count]
            func inset(_ other:NSPoint)->NSPoint {
                let length=hypot(other.x-point.x,other.y-point.y)
                let amount=min(radius/length,0.3)
                return p(point.x+(other.x-point.x)*amount,point.y+(other.y-point.y)*amount)
            }
            let start=inset(prev),end=inset(next)
            if i==0 { path.move(to:start) } else { path.line(to:start) }
            path.curve(to:end,controlPoint1:point,controlPoint2:point)
        }
        path.close();return path
    }
    private func p(_ x:CGFloat,_ y:CGFloat)->NSPoint { NSPoint(x:x,y:y) }
}
