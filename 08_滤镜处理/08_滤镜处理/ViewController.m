//
//  ViewController.m
//  08_滤镜处理
//
//  Created by 张喜千 on 2020/8/11.
//  Copyright © 2020 张喜千. All rights reserved.
//

#import "ViewController.h"
#import "FilterBar.h"
#import <GLKit/GLKit.h>

typedef struct {
    GLKVector3 positionCoord;//(X, Y, Z)
    GLKVector2 textureCoor;  //(U,V)
} SenceVertex;

@interface ViewController ()<FilterBarDelegate>
/** <#dis#> **/
@property (nonatomic,assign) SenceVertex *vertices;
/** <#dis#> **/
@property (nonatomic,strong) EAGLContext *context;
/** 用于刷新屏幕 **/
@property (nonatomic,strong) CADisplayLink *displayLink;
/** 开始的时间戳 **/
@property (nonatomic,assign) NSTimeInterval startTimeInterval;
/** 着色器程序 **/
@property (nonatomic,assign) GLuint program;
/** 顶点缓存 **/
@property (nonatomic,assign) GLuint vertexBuffer;
/** 纹理 ID **/
@property (nonatomic,assign) GLuint textureID;

@end

@implementation ViewController
//释放
- (void)dealloc
{
    //上下文释放
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    //顶点缓存区释放
    if (_vertexBuffer) {
        glDeleteBuffers(1, &_vertexBuffer);
        _vertexBuffer = 0;
    }
    //顶点数组释放
    if (_vertices) {
        free(_vertices);
        _vertices = nil;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    //移除 displayerLink
    if(self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}
- (void)viewDidLoad {
    [super viewDidLoad];
    //设置背景颜色
    self.view.backgroundColor = [UIColor blackColor];
    //创建滤镜工具栏
    [self setupFilterBar];
    //滤镜处理初始化
    [self filterInit];
    //开始一个滤镜动画
    [self startFilterAnimation];
}

//创建滤镜工具栏
- (void)setupFilterBar
{
    CGFloat filterBarWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat filterBarHeight = 100;
    CGFloat filterBarY = [UIScreen mainScreen].bounds.size.height - filterBarHeight;
    FilterBar *filerBar = [[FilterBar alloc] initWithFrame:CGRectMake(0, filterBarY, filterBarWidth, filterBarHeight)];
    filerBar.delegate = self;
    [self.view addSubview:filerBar];
    
    NSArray *dataSource = @[@"无",@"分屏_2",@"分屏_3",@"分屏_4",@"分屏_6",@"分屏_9"];
    filerBar.itemList = dataSource;
}
//滤镜处理初始化
- (void)filterInit
{
    
    //1.初始化上下文并设置为当前上下文
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.context];

    //2.开辟顶点数组内存空间
    self.vertices = malloc(sizeof(SenceVertex) * 4);

    //3.初始化顶点（0，1，2，3）的顶点坐标以及纹理坐标
    self.vertices[0] = (SenceVertex){{-1, 1, 0}, {0, 1}};
    self.vertices[1] = (SenceVertex){{-1, -1, 0}, {0, 0}};
    self.vertices[2] = (SenceVertex){{1, 1, 0}, {1, 1}};
    self.vertices[3] = (SenceVertex){{1, -1, 0}, {1, 0}};

    //4.创建图层
    CAEAGLLayer *layer = [[CAEAGLLayer alloc] init];

    layer.frame = CGRectMake(0, 100, self.view.frame.size.width, self.view.frame.size.width);
    //设置图层的scale
    layer.contentsScale = [[UIScreen mainScreen] scale];
    [self.view.layer addSublayer:layer];


    //5.绑定渲染缓存区
    [self bindRenderLayer:layer];

    //6.获取处理的图片路径
    NSString *imagePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"kunkun.jpg"];

    //读取图片
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    //将JPG图片转换成纹理图片
    GLuint textureID = [self createTextureWithImage:image];
    //设置纹理ID, 保存纹理，方便后面切换滤镜的时候重用
    self.textureID = textureID;

    //设置视口
    glViewport(0, 0, self.drawableWidth, self.drawableHeight);

    //8.设置顶点缓存区
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(SenceVertex) * 4;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices, GL_STATIC_DRAW);

    //9.设置默认着色器
    [self setupNormalShaderProgram];

    //10.将顶点缓存保存，退出时才释放
    self.vertexBuffer = vertexBuffer;
}

//绑定渲染缓存区
- (void)bindRenderLayer:(CALayer<EAGLDrawable> *)layer
{
    //1.渲染缓存区，帧缓存区对象
    GLuint renderBuffer;
    GLuint frameBuffer;

    //2.获取帧渲染缓存区名称，绑定渲染缓存区以及将渲染缓存区与 layer 建立连接
    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];

    //3.获取帧缓存区名称，绑定帧缓存区以及将渲染缓存区附着到帧缓存区上
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuffer);
}

//从图片中加载纹理
- (GLuint)createTextureWithImage:(UIImage *)image
{
    //1.将 uiImage 转换为 CGImageRed
    CGImageRef cgImageRef = [image CGImage];
    if (!cgImageRef) {
        NSLog(@"Failed to load image");
        exit(1);
    }
    //2.
    GLuint width = (GLuint)CGImageGetWidth(cgImageRef);
    GLuint height = (GLuint)CGImageGetHeight(cgImageRef);
    CGRect rect = CGRectMake(0, 0, width, height);

    //获取图片的颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    //3.获取图片字节数
    void *imageData = malloc(width * height * 4);

    //4.创建上下文
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, width * 4, colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big);


    // 将图片番过来 （图片默认是倒置的）
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGColorSpaceRelease(colorSpace);
    CGContextClearRect(context, rect);

    //对图片进行重新绘制，得到一张新的解压缩后的位图
    CGContextDrawImage(context, rect, cgImageRef);

    //设置图片纹理属性
    //5. 获取纹理ID
    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);

    //6.载入纹理2D数据
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);

    //7.设置纹理属性
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    //绑定纹理
    glBindTexture(GL_TEXTURE_2D, 0);
    //释放
    CGContextRelease(context);
    free(imageData);


    return textureID;
}

//开始一个滤镜动画
- (void)startFilterAnimation
{
    //1.判断displayLink 是否为空
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
    
    //2.设置displayLink的方法
    self.startTimeInterval = 0;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(timeAction)];
    
    //3.将 displayLink 添加到 runloop 运行循环
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

//动画
- (void)timeAction
{
    //DisplayLink 的当前时间撮
    if (self.startTimeInterval == 0) {
        self.startTimeInterval = self.displayLink.timestamp;
    }
    //使用program
    glUseProgram(self.program);
    //绑定buffer
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    
    // 传入时间
    CGFloat currentTime = self.displayLink.timestamp - self.startTimeInterval;
    GLuint time = glGetUniformLocation(self.program, "Time");
    glUniform1f(time, currentTime);
    
    // 清除画布
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(1, 1, 1, 1);
    
    // 重绘
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    //渲染到屏幕上
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)render
{
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(1, 1, 1, 1);
    
    glUseProgram(self.program);
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    
    //重缓
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - FilterBarDelegate
- (void)filterBar:(FilterBar *)filterBar didScrollToIndex:(NSUInteger)index
{
    if (index == 0) {
        [self setupNormalShaderProgram];
    } else if(index == 1){
        [self setupSplitScreen_2ShaderProgram];
    } else if (index == 2){
        [self setupSplitScreen_3ShaderProgram];
    }else if (index == 3){
        [self setupSplitScreen_4ShaderProgram];
    }else if (index == 4){
        [self setupSplitScreen_6ShaderProgram];
    }else if (index == 5){
        [self setupSplitScreen_9ShaderProgram];
    }
    
//    [self render];
    [self startFilterAnimation];
}

#pragma mark - shader
- (void)setupNormalShaderProgram
{
    [self setupShaderProgramWithName:@"Normal"];
}

- (void)setupSplitScreen_2ShaderProgram
{
    [self setupShaderProgramWithName:@"SplitScreen_2"];
}

- (void)setupSplitScreen_3ShaderProgram
{
    [self setupShaderProgramWithName:@"SplitScreen_3"];
}

- (void)setupSplitScreen_4ShaderProgram
{
    [self setupShaderProgramWithName:@"SplitScreen_4"];
}


- (void)setupSplitScreen_6ShaderProgram
{
    [self setupShaderProgramWithName:@"SplitScreen_6"];
}

- (void)setupSplitScreen_9ShaderProgram
{
    [self setupShaderProgramWithName:@"SplitScreen_9"];
}
// 初始化着色器程序
- (void)setupShaderProgramWithName:(NSString *)name
{
    GLuint program = [self programWithShaderName:name];
    
    glUseProgram(program);
    
    GLuint positionSlot = glGetAttribLocation(program, "Position");
    GLuint textureCoordsSlot = glGetAttribLocation(program, "TextureCoords");
    GLuint textureSlot = glGetUniformLocation(program, "Texture");
    
    
    //激活纹理，绑定纹理ID
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureID);
    
    //纹理sample
    glUniform1i(textureSlot, 0);
    
    //6.打开positionSlot 属性并且传递数据到positionSlot中(顶点坐标)
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, positionCoord));
    
    //7.打开textureCoordsSlot 属性并传递数据到textureCoordsSlot(纹理坐标)
    glEnableVertexAttribArray(textureCoordsSlot);
    glVertexAttribPointer(textureCoordsSlot, 2, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, textureCoor));
    //8.保存program,界面销毁则释放
    self.program = program;

}

#pragma mark - shader compile and link
//link Program
- (GLuint)programWithShaderName:(NSString *)shaderName
{
    //1.编译顶点着色器/片元着色器
    GLuint vertexShader = [self compileShaderWithName:shaderName type:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShaderWithName:shaderName type:GL_FRAGMENT_SHADER];
    
    //2.将顶点/片元附着到 program
    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    
    //3.linkProgram
    glLinkProgram(program);
    
    //4.检查是否 link 成功
    GLint linkSuccess;
    glGetProgramiv(program, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(program, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"program链接失败:%@", messageString);
        exit(1);
    }
    return program;
}

//编译shader代码
- (GLuint)compileShaderWithName:(NSString *)name type:(GLenum)shaderType
{
    //1.获取 shader 路径
    NSString *shaderPath = [[NSBundle mainBundle] pathForResource:name ofType:shaderType == GL_VERTEX_SHADER ? @"vsh" : @"fsh"];
    NSError *error;
    NSString *shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSAssert(NO, @"读取shader失败");
        exit(1);
    }
    
    //2创建shader -> 根据shaderType
    GLuint shader = glCreateShader(shaderType);
    
    //3.获取 shader source
    const char *shaderCode = [shaderString UTF8String];
    int shaderCodeLength = (int)[shaderString length];
    glShaderSource(shader, 1, &shaderCode, &shaderCodeLength);
    
    //4.编译shader
    glCompileShader(shader);
    
    //5.查看编译是否成功
    GLint compileSuccess;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shader, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"shader编译失败：%@",messageString);
        exit(1);
    }
    
    //6 返回shader
    return shader;
}



// 获取渲染缓存区的宽
- (GLint)drawableWidth
{
    GLint backingWidth;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    return backingWidth;
}
// 获取渲染缓存区的高
- (GLint)drawableHeight
{
    GLint backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    return backingHeight;
}
@end
