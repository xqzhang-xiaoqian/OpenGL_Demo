//
//  GView.m
//  05_GLSL_索引绘图_三角形变换
//
//  Created by 张喜千 on 2020/8/1.
//  Copyright © 2020 张喜千. All rights reserved.
//

#import "GView.h"
#import "GLESMath.h"
#import "GLESUtils.h"
#import <OpenGLES/ES2/gl.h>

@interface GView()
/** <#dis#> **/
@property (nonatomic,strong) CAEAGLLayer *myEagLayer;
/** <#dis#> **/
@property (nonatomic,strong) EAGLContext *myContext;
/** <#dis#> **/
@property (nonatomic,assign) GLuint myColorRenderBuffer;
/** <#dis#> **/
@property (nonatomic,assign) GLuint myColorFrameBuffer;

/** <#dis#> **/
@property (nonatomic,assign) GLuint myProgram;
/** <#dis#> **/
@property (nonatomic,assign) GLuint myVertices;

@end


@implementation GView
{
    float xDegree;
    float yDegree;
    float zDegree;
    BOOL bX;
    BOOL bY;
    BOOL bZ;
    NSTimer *myTimer;
}

- (void)layoutSubviews
{
    // 1设置图层
    [self setupLayer];
    
    //2 创建图形上下文
    [self setupContext];
    
    //3. 清空缓存区
    [self deleteRenderAndFrameBuffer];
    
    //4. 设置RenderBuffer
    [self setupRenderBuffer];
    
    //5. 设置frameBuffer
    [self setupFrameBuffer];
    
    //6. 绘制
    [self renderLayer];
    
}

//6. 绘制
- (void)renderLayer
{
    glClearColor(0.3, 0.3, 0.3, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    CGFloat scale = [[UIScreen mainScreen] scale];
    glViewport(self.frame.origin.x * scale, self.frame.origin.y * scale, self.frame.size.width * scale, self.frame.size.height * scale);
    
    NSString *vertFile = [[NSBundle mainBundle]pathForResource:@"shaderv" ofType:@"vsh"];
    NSString *fragFile = [[NSBundle mainBundle]pathForResource:@"shaderf" ofType:@"fsh"];
    
    if (self.myProgram) {
        glDeleteProgram(self.myProgram);
        self.myProgram = 0;
    }
    
    self.myProgram = [self loadShader:vertFile frag:fragFile];
    
    //6.链接
    glLinkProgram(self.myProgram);
    GLint linkSuccess;
    glGetProgramiv(self.myProgram, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(self.myProgram, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"error %@", messageString);
        return;
    }
    // 7 使用program
    glUseProgram(self.myProgram);
    
    //8 设置顶点数组 & 索引数组
    //1)顶点数组  前三项顶点值，后3位颜色值
    GLfloat attrArr[] =
    {
        -0.5f, 0.5f, 0.0f,      1.0f, 0.0f, 1.0f, //左上0
        0.5f, 0.5f, 0.0f,       1.0f, 0.0f, 1.0f, //右上1
        -0.5f, -0.5f, 0.0f,     1.0f, 1.0f, 1.0f, //左下2
        
        0.5f, -0.5f, 0.0f,      1.0f, 1.0f, 1.0f, //右下3
        0.0f, 0.0f, 1.0f,       0.0f, 1.0f, 0.0f, //顶点4
    };
    //2).索引数组
    GLuint indices[] =
    {
        0, 3, 2,
        0, 1, 3,
        0, 2, 4,
        0, 4, 1,
        2, 3, 4,
        1, 4, 3,
    };
    
    //9.-----处理顶点数据-------
    if (self.myVertices == 0) {
        glGenBuffers(1, &_myVertices);
    }
    glBindBuffer(GL_ARRAY_BUFFER, _myVertices);
    //将顶点数据从CPU内存复制到 GPU 上
    glBufferData(GL_ARRAY_BUFFER, sizeof(attrArr), attrArr, GL_DYNAMIC_DRAW);
    
    //10 打开顶点数据通道
    //获取顶点数据通道ID
    GLuint position = glGetAttribLocation(self.myProgram, "position");
    glEnableVertexAttribArray(position);
    glVertexAttribPointer(position, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 6, NULL);
    
    //11.处理顶点颜色值
    GLuint positionColor = glGetAttribLocation(self.myProgram, "positionColor");
    glEnableVertexAttribArray(positionColor);
    glVertexAttribPointer(positionColor, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 6, (float *)NULL + 3);
    
    //12.找到 myProgram中的 projectionMatrix、 modelViewMatrix 2个矩阵的地址。如果找到则返回地址，否则返回-1，表示没有找到2个对象
    GLuint projectionMatrixSlot = glGetUniformLocation(self.myProgram, "projectionMatrix");
    GLuint modelViewMatrixSlot = glGetUniformLocation(self.myProgram, "modelViewMatrix");
    
    float width = self.frame.size.width;
    float height = self.frame.size.height;
    
    //13.创建 4*4 投影矩阵
    KSMatrix4 _projectionMatrix;
    //1). 获取单元矩阵
    ksMatrixLoadIdentity(&_projectionMatrix);
    //2).计算纵横比例 = 长/宽
    float aspect = width / height;
    //3).获取透视矩阵
    ksPerspective(&_projectionMatrix, 30.0, aspect, 5.0f, 20.0f);// 透视变换，视角30度
    //4).将投影矩阵传递到顶点着色器
    /*
    void glUniformMatrix4fv(GLint location,  GLsizei count,  GLboolean transpose,  const GLfloat *value);
    参数列表：
    location:指要更改的uniform变量的位置
    count:更改矩阵的个数
    transpose:是否要转置矩阵，并将它作为uniform变量的值。必须为GL_FALSE
    value:执行count个元素的指针，用来更新指定uniform变量
    */
    glUniformMatrix4fv(projectionMatrixSlot, 1, GL_FALSE, (GLfloat *)&_projectionMatrix.m[0][0]);
    
    //14.创建4*4 矩阵，模型视图矩阵
    KSMatrix4 _modelViewMatrix;
    //1).获取单元矩阵
    ksMatrixLoadIdentity(&_modelViewMatrix);
    //2).平移，z轴平移-10
    ksTranslate(&_modelViewMatrix, 0.0, 0.0, -10.0);
    //3).创建一个 4*4 矩阵，旋转矩阵
    KSMatrix4 _rotationMatrix;
    //4).初始化为单元矩阵
    ksMatrixLoadIdentity(&_rotationMatrix);
    //5).旋转
    ksRotate(&_rotationMatrix, xDegree, 1.0, 0.0, 0.0);// 绕x轴
    ksRotate(&_rotationMatrix, yDegree, 0.0, 1.0, 0.0);// 绕y轴
    ksRotate(&_rotationMatrix, zDegree, 0.0, 0.0, 1.0);// 绕z轴
    //6).把变换矩阵相乘。将_modelViewMatrix 矩阵 与 _rotationMatrix矩阵相乘，结合到模型视图
    ksMatrixMultiply(&_modelViewMatrix, &_rotationMatrix, &_modelViewMatrix);
    //7).将模型视图矩阵传递到顶点着色器
    /*
    void glUniformMatrix4fv(GLint location,  GLsizei count,  GLboolean transpose,  const GLfloat *value);
    参数列表：
    location:指要更改的uniform变量的位置
    count:更改矩阵的个数
    transpose:是否要转置矩阵，并将它作为uniform变量的值。必须为GL_FALSE
    value:执行count个元素的指针，用来更新指定uniform变量
    */
    glUniformMatrix4fv(modelViewMatrixSlot, 1, GL_FALSE, (GLfloat *)&_modelViewMatrix.m[0][0]);
    
    //15.开启剔除操作效果
    glEnable(GL_CULL_FACE);
    
    //16.使用索引绘图
    glDrawElements(GL_TRIANGLES, sizeof(indices) / sizeof(indices[0]), GL_UNSIGNED_INT, indices);
    
    //17.要求本地窗口系统显示OpenGL ES 渲染<目标>
    [self.myContext presentRenderbuffer:GL_RENDERBUFFER];
}

//5. 设置frameBuffer
- (void)setupFrameBuffer
{
    GLuint buffer;
    glGenFramebuffers(1, &buffer);
    self.myColorFrameBuffer = buffer;
    glBindFramebuffer(GL_FRAMEBUFFER, self.myColorFrameBuffer);
    
    //将渲染缓存区和帧缓存区绑定到 GL_COLOR_ATTACHMENT0上
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, self.myColorRenderBuffer);
}
//4. 设置RenderBuffer
- (void)setupRenderBuffer
{
    GLuint buffer;
    glGenBuffers(1, &buffer);
    
    self.myColorRenderBuffer = buffer;
    
    glBindRenderbuffer(GL_RENDERBUFFER, self.myColorRenderBuffer);
    // 将可绘制对象的存储 绑定到 renderBuffer 对象
    [self.myContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.myEagLayer];
}

//3. 清空缓存区
- (void)deleteRenderAndFrameBuffer
{
    glDeleteRenderbuffers(1, &_myColorRenderBuffer);
    self.myColorRenderBuffer = 0;
    
    glDeleteBuffers(1, &_myColorFrameBuffer);
    self.myColorFrameBuffer = 0;
}

// 2.创建图形上下文
- (void)setupContext
{
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!context) {
        NSLog(@"create ES context failed!");
        return;
    }
    if (![EAGLContext setCurrentContext:context]) {
        NSLog(@"setCurrentContext failed!");
        return;
    }
    self.myContext = context;
}

// 1设置图层
- (void)setupLayer
{
    self.myEagLayer = (CAEAGLLayer *)self.layer;
    [self setContentScaleFactor:[[UIScreen mainScreen] scale]];
    
    self.myEagLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:@false, kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
}


+ (Class)layerClass
{
    return [CAEAGLLayer class];
}
#pragma mark - shader
- (GLuint)loadShader:(NSString *)vert frag:(NSString *)frag
{
    //创建两个临时变量
    GLuint verShader, fragShader;
    //创建空的 program
    GLuint program = glCreateProgram();
    
    //编译文件，编译顶点着色器，片元着色器程序
    /*
     参数1：编译完存储的底层地址
     参数2：编译的类型 GL_VERTEX_SHADER(顶点）,GL_FRAGMENT_SHADER(片元）
     */
    [self compileShader:&verShader type:GL_VERTEX_SHADER file:vert];
    [self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:frag];
    
    //创建最终的程序
    glAttachShader(program, verShader);
    glAttachShader(program, fragShader);
    
    //释放
    glDeleteShader(verShader);
    glDeleteShader(fragShader);
    
    return program;
}

- (void)compileShader:(GLuint*)shader type:(GLenum)type file:(NSString *)file
{
    //读取文件符串
    NSString *context = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    const GLchar *source = (GLchar *)[context UTF8String];
    
    //创建 shader 根据类型
    *shader = glCreateShader(type);
    
    //将顶点着色器源码附加到着色器对象上
    //参数1：shader,要编译的着色器对象 *shader
    //参数2：numOfStrings,传递的源码字符串数量 1个
    //参数3：strings,着色器程序的源码（真正的着色器程序源码）
    //参数4：lenOfStrings,长度，具有每个字符串长度的数组，或NULL，这意味着字符串是NULL终止的
    glShaderSource(*shader, 1, &source, NULL);
    
    //把着色器源代码编译成目标代码
    glCompileShader(*shader);
}

#pragma mark - xyClick

- (IBAction)xClick:(id)sender {
    //开启定时器
    if (!myTimer) {
        myTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(reDegree) userInfo:nil repeats:YES];
    }
    //更新的是x 还是 Y
    bX = !bX;
}

- (IBAction)yClick:(id)sender {
    //开启定时器
    if (!myTimer) {
        myTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(reDegree) userInfo:nil repeats:YES];
    }
    bY = !bY;
}

- (IBAction)zClick:(id)sender {
    //开启定时器
    if (!myTimer) {
        myTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(reDegree) userInfo:nil repeats:YES];
    }
    bZ = !bZ;
}

- (void)reDegree
{
    //如果停止X轴旋转，X = 0则度数就停留在暂停前的度数.
    //更新度数
    xDegree += bX * 5;
    yDegree += bY * 5;
    zDegree += bZ * 5;
    //重新渲染
    [self renderLayer];
}

@end
