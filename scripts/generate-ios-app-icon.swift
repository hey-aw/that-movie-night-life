import AppKit
import ImageIO
import UniformTypeIdentifiers
let n=1024
let context=CGContext(data:nil,width:n,height:n,bitsPerComponent:8,bytesPerRow:n*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red:0.055,green:0.055,blue:0.065,alpha:1));context.fill(CGRect(x:0,y:0,width:n,height:n))
let gold=CGColor(red:0.91,green:0.72,blue:0.22,alpha:1)
context.setFillColor(gold);context.addPath(CGPath(roundedRect:CGRect(x:200,y:220,width:624,height:584),cornerWidth:74,cornerHeight:74,transform:nil));context.fillPath()
context.setFillColor(CGColor(red:0.055,green:0.055,blue:0.065,alpha:1));context.addPath(CGPath(roundedRect:CGRect(x:280,y:296,width:464,height:432),cornerWidth:26,cornerHeight:26,transform:nil));context.fillPath()
context.setFillColor(gold);let triangle=CGMutablePath();triangle.move(to:CGPoint(x:438,y:382));triangle.addLine(to:CGPoint(x:438,y:642));triangle.addLine(to:CGPoint(x:647,y:512));triangle.closeSubpath();context.addPath(triangle);context.fillPath()
context.setFillColor(CGColor(red:0.055,green:0.055,blue:0.065,alpha:1))
for x in [224,768] {for y in [286,394,502,610,718] {context.addPath(CGPath(roundedRect:CGRect(x:x,y:y,width:32,height:52),cornerWidth:8,cornerHeight:8,transform:nil));context.fillPath()}}
let dest=CGImageDestinationCreateWithURL(URL(fileURLWithPath:CommandLine.arguments[1]) as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(dest,context.makeImage()!,nil);assert(CGImageDestinationFinalize(dest))
