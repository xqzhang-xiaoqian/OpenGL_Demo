//
//  ViewController.m
//  05_GLKit_索引绘图_三角形变换
//
//  Created by 张喜千 on 2020/8/1.
//  Copyright © 2020 张喜千. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
/** <#dis#> **/
@property (nonatomic,strong) EAGLContext *myContext;
/** <#dis#> **/
@property (nonatomic,strong) GLKBaseEffect *myEffect;

/** <#dis#> **/
@property (nonatomic,assign) int count;

// 旋转的度数
/** <#dis#> **/
@property (nonatomic,assign) float XDegree;
/** <#dis#> **/
@property (nonatomic,assign) float YDegree;
/** <#dis#> **/
@property (nonatomic,assign) float ZDegree;


// 是否旋转 X,Y,Z
/** <#dis#> **/
@property (nonatomic,assign) BOOL XB;
/**  **/
@property (nonatomic,assign) BOOL YB;
/** <#dis#> **/
@property (nonatomic,assign) BOOL ZB;
@end

@implementation ViewController
{
    dispatch_source_t timer;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    //1.新建图层
    [self setupContext];
    
    //2.渲染图层
    [self render];
}
//2.渲染图层
- (void)render
{
    //1.顶点数据
    //前3个元素是顶点数据；后三个元素是顶点颜色值
    GLfloat attrArr[] =
    {
        -0.5f, 0.5f, 0.0f,      1.0f, 0.0f, 1.0f, //左上
        0.5f, 0.5f, 0.0f,       1.0f, 0.0f, 1.0f, //右上
        -0.5f, -0.5f, 0.0f,     1.0f, 1.0f, 1.0f, //左下
        
        0.5f, -0.5f, 0.0f,      1.0f, 1.0f, 1.0f, //右下
        0.0f, 0.0f, 1.0f,       0.0f, 1.0f, 0.0f, //顶点
    };
    
    //2.绘图索引
    GLuint indices[] =
    {
        0, 3, 2,
        0, 1, 3,
        0, 2, 4,
        0, 4, 1,
        2, 3, 4,
        1, 4, 3,
    };
    
   // 3.顶点个数
    self.count = sizeof(indices) / sizeof(GLuint);
    
    //4.将顶点数组放入数组缓冲区中 GL_ARRAY_BUFFER
    GLuint buffer;
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(attrArr), attrArr, GL_STATIC_DRAW);
    
    //将索引数组存储到索引缓冲区 GL_ELEMENT_ARRAY_BUFER
    GLuint index;
    glGenBuffers(1, &index);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, index);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    
    //5.使用顶点数据
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 6, NULL);
    
    //6.使用颜色数据
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 6, (float *)NULL + 3);
    
    //着色器
    self.myEffect = [[GLKBaseEffect alloc] init];
    
    //投影视图
    CGSize size = self.view.bounds.size;
    float aspect = fabs(size.width / size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(90.0), aspect, 0.1f, 100.0);
    projectionMatrix = GLKMatrix4Scale(projectionMatrix, 1.0f, 1.0f, 1.0f);
    self.myEffect.transform.projectionMatrix = projectionMatrix;
    
    //模型视图
    GLKMatrix4 modelViewMatrix = GLKMatrix4Translate(GLKMatrix4Identity, 0.0f, 0.0f, -2.0f);
    self.myEffect.transform.modelviewMatrix = modelViewMatrix;
    
    //定时器
    double seconds = 0.1;
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC, 0.0);
    dispatch_source_set_event_handler(timer, ^{
        
        self.XDegree += 0.1f * self.XB;
        self.YDegree += 0.1f * self.YB;
        self.ZDegree += 0.1f * self.ZB;
        
    });
    dispatch_resume(timer);
    
}

- (void)update
{
    GLKMatrix4 modelViewMatrix = GLKMatrix4Translate(GLKMatrix4Identity, 0.0f, 0.0f, -2.5);
    
    modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, self.XDegree);
    modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, self.YDegree);
    modelViewMatrix = GLKMatrix4RotateZ(modelViewMatrix, self.ZDegree);
    
    self.myEffect.transform.modelviewMatrix = modelViewMatrix;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glClearColor(0.3f, 0.3f, 0.3f, 1.0f);
    
    [self.myEffect prepareToDraw];
    glDrawElements(GL_TRIANGLES, self.count, GL_UNSIGNED_INT, 0);
}

// 1.新建图层
- (void)setupContext
{
    //1.新建OpenGL ES 上下文
    self.myContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.myContext;
    view.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [EAGLContext setCurrentContext:self.myContext];
    //开启深度测试
    glEnable(GL_DEPTH_TEST);
}

#pragma mark - xyzClick

- (IBAction)xClick:(id)sender {
    _XB = !_XB;
}

- (IBAction)yClick:(id)sender {
    _YB = !_YB;
}

- (IBAction)zClick:(id)sender {
    _ZB = !_ZB;
}

@end
