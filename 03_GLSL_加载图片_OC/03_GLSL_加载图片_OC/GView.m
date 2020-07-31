//
//  GView.m
//  03_GLSL_加载图片_OC
//
//  Created by 张喜千 on 2020/7/30.
//  Copyright © 2020 张喜千. All rights reserved.
//

/*
    不采用GLKBaseEffect, 使用编译链接自定义着色器shader。用简单的glsl语言来实现顶点、片元着色器，并图形进行简单的变换。
 思路：
    1.创建图层
    2.创建上下文
    3.清空缓存区
    4.设置 RenderBuffer
    5.设置 FrameBuffer
    6.开始绘制
 */

#import "GView.h"
#import <OpenGLES/ES2/gl.h>

@interface GView ()

/** 在iOS 和 tvOS 上绘制 OpenGL ES 内容的图层，继承于 CALayer **/
@property (nonatomic,strong) CAEAGLLayer *myEaglLayer;
/** 上下文 **/
@property (nonatomic,strong) EAGLContext *myContext;
/** 渲染缓存区， 渲染缓存区需要附着在帧缓存区上 **/
@property (nonatomic,assign) GLuint *myColorRenderBuffer;
/** 帧缓存区 **/
@property (nonatomic,assign) GLuint *myColorFrameBuffer;
/** <#dis#> **/
@property (nonatomic,assign) GLuint *myPrograme;


@end

@implementation GView


- (void)layoutSubviews
{
    //1.创建特殊图层
    [self setupLayer];
    //2.创建图形上下文
    [self setupContext];
    
    //3.清空缓存区
    [self deleteRenderAndFrameBuffer];
    
    //4.设置RenderBuffer
    [self setupRenderBuffer];
    
    //5.设置FrameBuffer
    [self setupFrameBuffer];
    
    //6.开始绘制
    [self renderLayer];
}

//6.开始绘制
- (void)renderLayer
{
    //1.设置清屏颜色
    glClearColor(0.3f, 0.3f, 0.5f, 1);
    
    //2.清除颜色缓存区
    glClear(GL_COLOR_BUFFER_BIT);
    
    //3.设置视口大小
    //UIscreen获得的是逻辑大小 openGL的作用范围是像素 所以要乘缩放因子
    CGFloat scale = [[UIScreen mainScreen] scale];
    glViewport(self.frame.origin.x * scale, self.frame.origin.y * scale, self.frame.size.width * scale, self.frame.size.height * scale);
    
    //4.读取顶点着色器，片元着色器
    NSString *vertFile = [[NSBundle mainBundle] pathForResource:@"shaderv" ofType:@"vsh"];
    NSString *fragFile = [[NSBundle mainBundle] pathForResource:@"shaderf" ofType:@"fsh"];
    NSLog(@"vertFile:%@",vertFile);
    NSLog(@"fragFile:%@", fragFile);
    
    //5. 加载shader
    self.myPrograme = [self loadShaders:vertFile Withfrag:fragFile];
    
    //6.program链接
    glLinkProgram(self.myPrograme);
    GLint linkStatus;
    //获取链接状态，并做失败处理
    glGetProgramiv(self.myPrograme, GL_LINK_STATUS, &linkStatus);
    if (linkStatus == GL_FALSE) {
        GLchar message[512];
        glGetProgramInfoLog(self.myPrograme, sizeof(message), 0, &message[0]);
        NSString *messageString = [NSString stringWithUTF8String:message];
        NSLog(@"Program Link Errlr:%@", messageString);
        return;
    }
    NSLog(@"Program link success!");
    
    //7.使用program
    glUseProgram(self.myPrograme);
    
    //8.设置顶点坐标、纹理坐标
    //前3个是顶点坐标，后2个是纹理坐标
    GLfloat attrArr[] =
    {
        0.5f, -0.5f, -1.0f,     1.0f, 0.0f, //右下
        -0.5f, 0.5f, -1.0f,     0.0f, 1.0f, //左上
        -0.5f, -0.5f, -1.0f,    0.0f, 0.0f, //左下
        
        0.5f, 0.5f, -1.0f,      1.0f, 1.0f, //右上
        -0.5f, 0.5f, -1.0f,     0.0f, 1.0f, //左上
        0.5f, -0.5f, -1.0f,     1.0f, 0.0f, //右下
    };
    
    //9.-----处理顶点数据------
    //1).顶点缓存区
    GLuint attrBuffer;
    
    //2).申请一个缓存区标识符
    glGenBuffers(1, &attrBuffer);
    
    //3).将 attrBuffer 绑定到 GL_ARRAY_BUFFER 标识符上
    glBindBuffer(GL_ARRAY_BUFFER, attrBuffer);
    
    //4).将顶点数据从 CPU 内存复制到 GPU 上
    glBufferData(GL_ARRAY_BUFFER, sizeof(attrArr), attrArr, GL_DYNAMIC_DRAW);
    
    //10.----打开通道---
    //将顶点数据通过 myPrograme 中的传递到顶点着色器程序的position
    //1.glGetAttribLocation, 用来获取 vertex attribute的入口的
    //2.告诉OpenGL ES, 通过glEnableVertexAttribArray,
    //3.最后数据是通过glVertexAttribPointer传递过去的。
    
    //1).注意：第二个参数字符串必须和 shaderv.vsh 中的输入变量：position 保持一致
    GLuint position = glGetAttribLocation(self.myPrograme, "position");
    
    //2).设置合适的格式从 buffer 里面读取数据
    glEnableVertexAttribArray(position);
    
    //3).设置读取方式
    /*
     参数1：index,顶点数据的索引
     参数2：size,每个顶点属性的组件数量，1，2，3，或者4.默认初始值是4.
     参数3：type,数据中的每个组件的类型，常用的有GL_FLOAT,GL_BYTE,GL_SHORT。默认初始值为GL_FLOAT
     参数4：normalized,固定点数据值是否应该归一化，或者直接转换为固定值。（GL_FALSE）
     参数5：stride,连续顶点属性之间的偏移量，默认为0；
     参数6：指定一个指针，指向数组中的第一个顶点属性的第一个组件。默认为0
     */
    glVertexAttribPointer(position, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat)*5, NULL);
    
    //11.-----处理纹理数据----
    //1).glGetAttribLocation, 用来获取 vertex attribute的入口的
    //注意：第二个参数字符串必须和 shaderv.vsh 中的输入变量：textCoordinate 保持一致
    GLuint textCoor = glGetAttribLocation(self.myPrograme, "textCoordinate");
    
    //2).设置合适的格式从 buffer 里面读取数据
    glEnableVertexAttribArray(textCoor);
    
    //3).设置读取方式
    /*
     参数1：index,顶点数据的索引
     参数2：size,每个顶点属性的组件数量，1，2，3，或者4.默认初始值是4.
     参数3：type,数据中的每个组件的类型，常用的有GL_FLOAT,GL_BYTE,GL_SHORT。默认初始值为GL_FLOAT
     参数4：normalized,固定点数据值是否应该归一化，或者直接转换为固定值。（GL_FALSE）
     参数5：stride,连续顶点属性之间的偏移量，默认为0；
     参数6：指定一个指针，指向数组中的第一个顶点属性的第一个组件。默认为0
     */
    glVertexAttribPointer(textCoor, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat)*5, (float *)NULL + 3);
    
    //12.加载纹理
    [self setupTexture:@"qinxiaoxian"];
    
    //13.设置纹理采样器 sampler2D
    glUniform1i(glGetUniformLocation(self.myPrograme, "colorMap"), 0);
    
    //14.绘制
    glDrawArrays(GL_TRIANGLES, 0, 6);
    
    //15. 从渲染缓存区显示到屏幕上
    [self.myContext presentRenderbuffer:GL_RENDERBUFFER];
    
}

//加载纹理
- (GLuint)setupTexture:(NSString *)fileName
{
    //1.将 UIImage 转换为 CGImageRef
    CGImageRef spriteImage = [UIImage imageNamed:fileName].CGImage;
    if (!spriteImage) {
        NSLog(@"failed to load image %@", fileName);
        exit(1);
    }
    
    //2.读取图片的大小，宽 和 高
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    //3.获取图片字节数    宽*高*4（RGBA）
    GLubyte *spriteData = (GLubyte *)calloc(width * height * 4, sizeof(GLubyte));
    
    //4.创建上下文 CGContextRef
    /*
    参数1：data,指向要渲染的绘制图像的内存地址
    参数2：width,bitmap的宽度，单位为像素
    参数3：height,bitmap的高度，单位为像素
    参数4：bitPerComponent,内存中像素的每个组件的位数，比如32位RGBA，就设置为8
    参数5：bytesPerRow,bitmap的每一行的内存所占的比特数
    参数6：colorSpace,bitmap上使用的颜色空间
    参数7：kCGImageAlphaPremultipliedLast：RGBA
    */
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width * 4, CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    
    //5.在 CGContextRef 上绘制图片
    /*
    CGContextDrawImage 使用的是Core Graphics框架，坐标系与UIKit 不一样。UIKit框架的原点在屏幕的左上角，Core Graphics框架的原点在屏幕的左下角。
    CGContextDrawImage
    参数1：绘图上下文
    参数2：rect坐标
    参数3：绘制的图片
    */
    CGRect rect = CGRectMake(0, 0, width, height);
    //使用默认方式绘制
    CGContextDrawImage(spriteContext, rect, spriteImage);
    
    //6.画图完毕 释放上下文
    CGContextRelease(spriteContext);
    

    //7.绑定纹理到默认的纹理ID
//    glGenBuffers(1, 0);//这行代码可以省略，默认纹理ID是0， 纹理ID0一直是激活的状态
    glBindTexture(GL_TEXTURE_2D, 0);
    
    //8.设置纹理属性
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    float fw = width, fh = height;
    //9.载入纹理2D数据
    /*
    参数1：纹理模式，GL_TEXTURE_1D、GL_TEXTURE_2D、GL_TEXTURE_3D
    参数2：加载的层次，一般设置为0
    参数3：纹理的颜色值GL_RGBA
    参数4：宽
    参数5：高
    参数6：border，边界宽度
    参数7：format
    参数8：type
    参数9：纹理数据
    */
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fw, fh, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    
    //10.释放 spriteData
    free(spriteData);
    
    return 0;
}

//5. 设置FrameBuffer
- (void)setupFrameBuffer
{
    //1.定义一个缓存区ID
    GLuint buffer;
    
    //2.申请一个缓存区标志，（以下两个方法都可以）
//    glGenFramebuffers(1, &buffer);
    glGenBuffers(1, &buffer);
    self.myColorFrameBuffer = buffer;
    
    //3.将标识符绑定到GL_FRAMEBUFFER
    glBindFramebuffer(GL_FRAMEBUFFER, self.myColorFrameBuffer);
    /*
    生成帧缓存区之后，则需要将 renderbuffer 跟 framebuffer 进行绑定，
    调用glFramebufferRenderbuffer 函数进行绑定到对应的附着点上，后面的绘制才能起作用
    */
    
    //4.将渲染缓存区和帧缓存区绑定到 GL_COLOR_ATTACHMENTO上
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, self.myColorRenderBuffer);
}

//4. 设置RenderBuffer
- (void)setupRenderBuffer
{
    //1.定义一个缓存区ID
    GLuint buffer;
    
    //2.申请一个缓存区标志（两个方法都可以）
//    glGenRenderbuffers(1, &buffer);
    glGenBuffers(1, &buffer);
    self.myColorRenderBuffer = buffer;
    
    //3.将标志绑定到 GL_RENDERBUFFER
    glBindRenderbuffer(GL_RENDERBUFFER, self.myColorRenderBuffer);
    
    //4.将可绘制对象的存储绑定到 renderBuffer 对象
    // 将可绘制对象drawable object's CAEAGLLayer的存储 绑定到 OpenGL ES renderBuffer 对象
    [self.myContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.myEaglLayer];
}

//3.清空缓存区
- (void)deleteRenderAndFrameBuffer
{
    /*
     buffer 分为 frame buffer（帧缓存区） 和 render buffer（渲染缓存区）2大类。
     其中 frame buffer 相当于 render buffer的管理者。
     frame buffer object 即称 FBO.
     render buffer 则又可分为3类。colorBuffer、 depthBuffer、 stencilBuffer(模板缓存区)。
     */
    glDeleteBuffers(1, &_myColorRenderBuffer);
    self.myColorRenderBuffer = 0;
    
    glDeleteBuffers(1, &_myColorFrameBuffer);
    self.myColorFrameBuffer = 0;
}

//2.创建图形上下文
- (void)setupContext
{
    //1.创建图形上下文
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    //2.判断是否创建成功
    if (!context) {
        NSLog(@"Create ES context failed!");
        return;
    }
    
    //3.设置图形上下文
    if (![EAGLContext setCurrentContext:context]) {
        NSLog(@"setCurrentContext failed!");
        return;
    }
    
    self.myContext = context;
}

//1.创建特殊图层
- (void)setupLayer
{
    //1.创建列表图层
    /*
     重写 layerClass, 将GView返回的图层从CALayer替换成CAEAGLLayer
     */
    self.myEaglLayer = (CAEAGLLayer *)self.layer;
    
    //2.设置scale
    [self setContentScaleFactor:[[UIScreen mainScreen]scale]];
    
    //3.设置描述属性，这晨设置不维持渲染内容以及颜色格式为RGBA8(绘图表面完成后是否保留其内容，颜色缓冲区格式)
    /*
     kEAGLDrawablePropertyRetainedBacking  表示绘图表面显示后，是否保留其内容。
     kEAGLDrawablePropertyColorFormat
         可绘制表面的内部颜色缓存区格式，这个key对应的值是一个NSString指定特定颜色缓存区对象。默认是kEAGLColorFormatRGBA8；
     
         kEAGLColorFormatRGBA8：32位RGBA的颜色，4*8=32位
         kEAGLColorFormatRGB565：16位RGB的颜色，
         kEAGLColorFormatSRGBA8：sRGB代表了标准的红、绿、蓝，即CRT显示器、LCD显示器、投影机、打印机以及其他设备中色彩再现所使用的三个基本色素。sRGB的色彩空间基于独立的色彩坐标，可以使色彩在不同的设备使用传输中对应于同一个色彩坐标体系，而不受这些设备各自具有的不同色彩坐标的影响。
     */
    self.myEaglLayer.drawableProperties = @{
                kEAGLDrawablePropertyRetainedBacking:@false,
                kEAGLDrawablePropertyColorFormat:kEAGLColorFormatRGBA8};
    
}

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

#pragma mark - shader
// 加载shader
- (GLuint)loadShaders:(NSString *)vert Withfrag:(NSString *)frag
{
    //1.定义2个临时着色器对象  顶点着色器和片元着色器
    GLuint verShader, fragShader;
    //2. 创建program, 创建空的 program
    GLint program = glCreateProgram();
    
    //3.编译顶点着色器 和 片元着色器
    /*
     参数1：编译完存储的底层地址
     参数2：编译的类型：GL_VERTEX_SHADER(顶点)、GL_FRAGMENT_SHADER(片元)
     参数3：文件路径
     */
    [self compileShader:&verShader type:GL_VERTEX_SHADER file:vert];
    [self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:frag];
    
    //4.创建最终的程序, 编译好的shader 附着到 program
    glAttachShader(program, verShader);
    glAttachShader(program, fragShader);
    
    //5.释放不需要的shader
    glDeleteShader(verShader);
    glDeleteShader(fragShader);
    //返回program
    return program;
}
//编译 shader
- (void)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    //1.读取文件路径字符串
    NSString *content = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    const GLchar *source = (GLchar *)[content UTF8String];
    
    //2.创建一个对应类型的shader
    *shader = glCreateShader(type);
    
    //3.将着色器源码附加到着色器对象上
    /*
     参数1：shader 要编译的着色器对象 *shader
     参数2：numOfStrings,传递的源码字符串数量1个
     参数3：strings, 着色器程序的源码（真正的着色器程序源码）
     参数4：lenOfStrings,长度，具有每个字符串长度的数组，或NULL，这意味着字符串是NULL终止的
     */
    glShaderSource(*shader, 1, &source, NULL);
    
    //把着色器源代码编译成目标代码
    glCompileShader(*shader);
    
}
@end
