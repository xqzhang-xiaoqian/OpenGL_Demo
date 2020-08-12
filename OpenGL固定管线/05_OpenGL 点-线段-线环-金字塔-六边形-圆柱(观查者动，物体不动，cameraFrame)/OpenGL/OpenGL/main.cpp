//
//  main.cpp
//  OpenGL
//
//  Created by 张喜千 on 2020/8/2.
//  Copyright © 2020 张喜千. All rights reserved.
//

#include "GLTools.h"
//矩形工具类
//1、利用GLMatrixStack加载单元矩阵、矩阵、矩阵相乘、压栈、出栈、缩放、平移、旋转
#include "GLMatrixStack.h"
//2、表示位置，通过设置vOrigin、vForward、vUp
#include "GLFrame.h"
//3、用来快速设置正/透视投影矩阵，完成坐标从3D->2D的映射过程
#include "GLFrustum.h"
//三角形批次类，帮助类，用来传输顶点、光照、纹理、颜色数据到存储着色器
#include "GLBatch.h"
//变换管道类，用来快速在代码中传输视图矩阵、投影矩阵、视图投影矩阵等
#include "GLGeometryTransform.h"

#include <math.h>
#ifdef __APPLE__
#include <glut/glut.h>
#else
#define FREEGLUT_STATIC
#include <GL/glut.h>
#endif

/*
GLMatrixStack 变化管线使用矩阵堆栈

GLMatrixStack 构造函数允许指定堆栈的最大深度、默认的堆栈深度为64.这个矩阵堆在初始化时已经在堆栈中包含了单位矩阵。
GLMatrixStack::GLMatrixStack(int iStackDepth = 64);

//通过调用顶部载入这个单位矩阵
void GLMatrixStack::LoadIndentiy(void);

//在堆栈顶部载入任何矩阵
void GLMatrixStack::LoadMatrix(const M3DMatrix44f m);
*/

// 存储着色器管理工具类
GLShaderManager shaderManager;

//模型视图矩阵
GLMatrixStack modelViewMatrix;
//投影矩阵
GLMatrixStack projectionMatrix;

//设置观察者视图坐标
GLFrame         cameraFrame;
//设置图形环绕时，视图坐标
GLFrame         objectFrame;

//设置投影--图元绘制时的投影方式
GLFrustum       viewFrustum;

//容器类(7种不同的图元对应7种容器对象)
GLBatch     pointBatch;//点
GLBatch     lineBatch;//线
GLBatch     lineStripBatch;//线段
GLBatch     lineLoopBatch;//线环
GLBatch     triangleBatch;//金字塔
GLBatch     triangStripBatch;//六边形
GLBatch     triangleFanBatch;//圆柱

//几何变换的管道
GLGeometryTransform transformPipeline;

GLfloat vGreen[] = {0.0f, 1.0f, 0.0f, 1.0f};
GLfloat vBlack[] = {0.0f, 0.0f, 0.0f, 1.0f};

// 跟踪效果步骤--渲染不同的图形
int nStep = 0;


//此函数在呈现上下文中进行任何必要的初始化
//这是第一次做任何与opengl相关的任务
void setupRC()
{
    //1.初始化准备
    //背景颜色
    glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
    //存储着色器管理器初始化
    shaderManager.InitializeStockShaders();
    //开启深度测试
    glEnable(GL_DEPTH_TEST);
    //设置变换管道中模型视图矩阵/投影矩阵
    transformPipeline.SetMatrixStacks(modelViewMatrix, projectionMatrix);
    
    //设置观察者视图坐标的位置 ：up-y,right-x,forward-z
//    cameraFrame.MoveForward(-15.0f);
    
    //GLFrame中默认的方向是z轴的负方向 -- (0.0f, 0.0f, -1.0f)
    //参数：表示离屏幕之间的距离。负数是往屏幕后面移动。正数 往屏幕前面移动
    objectFrame.MoveForward(15.0f);
    
    //定义一些点
    GLfloat vCoast[9] = {
        3, 3, 0,
        0, 3, 0,
        3, 0, 0,
    };
    
    //2.点
    pointBatch.Begin(GL_POINTS, 3);
    pointBatch.CopyVertexData3f(vCoast);
    pointBatch.End();
    
    //线
    lineBatch.Begin(GL_LINES, 3);
    lineBatch.CopyVertexData3f(vCoast);
    lineBatch.End();
    
    //线段
    lineStripBatch.Begin(GL_LINE_STRIP, 3);
    lineStripBatch.CopyVertexData3f(vCoast);
    lineStripBatch.End();
    
    //线环
    lineLoopBatch.Begin(GL_LINE_LOOP, 3);
    lineLoopBatch.CopyVertexData3f(vCoast);
    lineLoopBatch.End();
    
    
    //绘制金字塔
    //定义金字塔顶点数据，利用三角形批次类 GL_TRIANGLES 绘制
    GLfloat vPyramid[12][3] = {
        -2.0f, 0.0f, -2.0f,
        2.0f, 0.0f, -2.0f,
        0.0f, 4.0f, 0.0f,
        
        2.0f, 0.0f, -2.0f,
        2.0f, 0.0f, 2.0f,
        0.0f, 4.0f, 0.0f,
        
        2.0f, 0.0f, 2.0f,
        -2.0f, 0.0f, 2.0f,
        0.0f, 4.0f, 0.0f,
        
        -2.0f, 0.0f, 2.0f,
        -2.0f, 0.0f, -2.0f,
        0.0f, 4.0f, 0.0f
    };
    //每三个顶点绘制一个新的三角形
    triangleBatch.Begin(GL_TRIANGLES, 12);
    triangleBatch.CopyVertexData3f(vPyramid);
    triangleBatch.End();
    
    //绘制六角形
    //循环定义顶点数据， 使用 GL_TRIANGLE_FAN传输数据
    GLfloat vPoints[100][3];//100个顶点，每个顶点都是xyz
    int nVerts = 0;//记录当前是第几个顶点
    //半径
    GLfloat r = 3.0f;
    //原点 （x，y，z） = （0，0，0）
    vPoints[nVerts][0] = 0.0f;
    vPoints[nVerts][1] = 0.0f;
    vPoints[nVerts][2] = 0.0f;
    
    //M3D_2PI 就是2Pi 的意思，就一个圆的意思。 绘制圆形, M3D_2PI / 6.0f 圆形角度6等分
    for (GLfloat angle = 0; angle < M3D_2PI; angle += M3D_2PI / 6.0f) {
        //数组下标自增
        nVerts++;
        //弧长=半径*角度
        //根据cos，可求 角度 = arccos
        //x点坐标 cos(angle) * 半径
        vPoints[nVerts][0] = float(cos(angle)) * r;
        //y点坐标 sin(angle) * 半径
        vPoints[nVerts][1] = float(sin(angle)) * r;
        //z点的坐标
        vPoints[nVerts][2] = -0.5f;
    }
    // 结束扇形 前面一共绘制7个顶点（包括圆心）
    //添加闭合的终点
    nVerts++;
    vPoints[nVerts][0] = r;
    vPoints[nVerts][1] = 0;
    vPoints[nVerts][2] = 0.0f;
    
    triangleFanBatch.Begin(GL_TRIANGLE_FAN, 8);
    triangleFanBatch.CopyVertexData3f(vPoints);
    triangleFanBatch.End();
    
    //绘制三角形环
    //使用GL_TRIANGLE_STRIP传输数据
    //顶点下标
    int iCounter = 0;
    //半径
    GLfloat radius = 3.0f;
    //从0度~360度，以0.3弧度为步长
    for (GLfloat angle = 0.0f; angle <= 2.0*M3D_PI; angle += 0.3f) {
        //圆形顶点的x，y
        GLfloat x = radius * sin(angle);
        GLfloat y = radius * cos(angle);
        
        //绘制两个三角形（他们的x,y顶点一样，只是z点不一样）
        vPoints[iCounter][0] = x;
        vPoints[iCounter][1] = y;
        vPoints[iCounter][2] = -0.5;
        iCounter++;
        
        vPoints[iCounter][0] = x;
        vPoints[iCounter][1] = y;
        vPoints[iCounter][2] = 0.5;
        iCounter++;
    }
    
    //关闭循环：结束循环，在循环位置生成2个三角形
    vPoints[iCounter][0] = vPoints[0][0];
    vPoints[iCounter][1] = vPoints[0][1];
    vPoints[iCounter][2] = -0.5;
    iCounter++;
    
    vPoints[iCounter][0] = vPoints[1][0];;
    vPoints[iCounter][1] = vPoints[1][1];
    vPoints[iCounter][2] = 0.5;
    iCounter++;
    
    // GL_TRIANGLE_STRIP 共用一个条带（strip）上的顶点的一组三角形
    triangStripBatch.Begin(GL_TRIANGLE_STRIP, iCounter);
    triangStripBatch.CopyVertexData3f(vPoints);
    triangStripBatch.End();
}

void drawWriteFrameBatch(GLBatch *pBatch)
{
    //1.填充图形内容
    shaderManager.UseStockShader(GLT_SHADER_FLAT, transformPipeline.GetModelViewProjectionMatrix(), vGreen);
    pBatch -> Draw();
    //2.绘制边框部分
    //多边形偏移：在同一位置要绘制填充和边线，会产生z冲突，所以要偏移
    glPolygonOffset(-1.0f, -1.0f);
    //启用线的深度偏移
    glEnable(GL_POLYGON_OFFSET_LINE);
    //画反锯齿：让黑边好看些
    glEnable(GL_LINE_SMOOTH);
    //颜色混合
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    //绘制边框
    //绘制线框几何黑色版 三种模式，实心，边框，点，可以作用在正面，背面，或者两面
    //通过调用glPolygonMode将多边形正面或者背面设为线框模式，实现线框渲染
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
    //设置线条宽度
    glLineWidth(4.0f);
    
    shaderManager.UseStockShader(GLT_SHADER_FLAT,transformPipeline.GetModelViewProjectionMatrix(), vBlack);
    pBatch -> Draw();
    
    //3.将设置的属性还原
    //通过调用glPolygonMode将多边形正面或者背面设为全部填充模式
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    glDisable(GL_POLYGON_OFFSET_LINE);
    glLineWidth(1.0f);
    glDisable(GL_BLEND);
    glDisable(GL_LINE_SMOOTH);
}

void RenderScene(void)
{
    //清理缓存区
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    //将aCamera观察者坐标系统压栈
    //将aObjectFrame 图形环绕坐标系压栈
    //压栈
    modelViewMatrix.PushMatrix();
    
    //cameraFrame 不是矩阵，将 cameraFrame 构建成 观察者矩阵
//    M3DMatrix44f mCamera;
//    cameraFrame.GetCameraMatrix(mCamera);
//
//    //矩阵*矩阵堆栈的顶部矩阵，结果随后存储在堆栈的顶部
//    //观察者矩阵* 栈顶单元矩阵= 新观察者矩阵，压栈
//    modelViewMatrix.MultMatrix(mCamera);
//
//    //利用mObjectFrame 构建成物体矩阵
//    M3DMatrix44f mObjectFrame;
//    //只要使用 GetMatrix 函数就可以获取矩阵堆栈顶部的值，这个函数可以进行2次重载。用来使用 GLShaderManager 的使用。或者是获取顶部矩阵的顶点副本数据
//    objectFrame.GetMatrix(mObjectFrame);
//
//    //矩阵乘以矩阵堆栈的顶部矩阵，相乘的结果随后存储在堆栈的顶部
//
//    //栈顶观察者矩阵*物体矩阵 = 模型视图矩阵，将模型视图矩阵压栈
//    modelViewMatrix.MultMatrix(mObjectFrame);
    
    
    //此时的 objectFrame 是观察者
    modelViewMatrix.PushMatrix(objectFrame);
    
    //固定管线渲染 点，线，线段....
    shaderManager.UseStockShader(GLT_SHADER_FLAT, transformPipeline.GetModelViewProjectionMatrix(),vBlack);
    switch (nStep) {
        case 0:
            //设置点的大小
            glPointSize(4.0f);
            pointBatch.Draw();
            glPointSize(1.0f);
            break;
        case 1:
            glLineWidth(4.0f);
            lineBatch.Draw();
            glLineWidth(1.0f);
            break;
        case 2:
            glLineWidth(4.0f);
            lineStripBatch.Draw();
            glLineWidth(1.0f);
            break;
        case 3:
            glLineWidth(4.0f);
            lineLoopBatch.Draw();
            glLineWidth(1.0f);
            break;
        case 4:
            drawWriteFrameBatch(&triangleBatch);
            break;
        case 5:
            drawWriteFrameBatch(&triangleFanBatch);
            break;
        case 6:
            drawWriteFrameBatch(&triangStripBatch);
            break;
    }
    
    // 绘制完毕则还原矩阵
    modelViewMatrix.PopMatrix();
    
    //交换缓存区
    glutSwapBuffers();
    
    
}



//在窗口大小改变时，接收新的宽度&高度。
void changeSize(int w,int h)
{
    glViewport(0, 0, w, h);
    //创建投影矩阵，并将它载入投影矩阵堆栈中
    viewFrustum.SetPerspective(35.0f, float(w)/float(h), 1.0f, 100.0f);
    projectionMatrix.LoadMatrix(viewFrustum.GetProjectionMatrix());
    
    //调用顶点载入单元矩阵
    modelViewMatrix.LoadIdentity();
}

void SpecialKeys(int key, int x, int y)
{
    if (key == GLUT_KEY_UP) {
        //围绕一个指定的 xyz 旋转 ,x轴
        objectFrame.RotateWorld(m3dDegToRad(-5), 1.0f, 0.0f, 0.0f);
    }
    if (key == GLUT_KEY_DOWN) {
        objectFrame.RotateWorld(m3dDegToRad(5), 1.0f, 0.0f, 0.0f);
    }
    if (key == GLUT_KEY_LEFT) {
        objectFrame.RotateWorld(m3dDegToRad(-5), 0.0f, 1.0f, 0.0f);
    }
    if (key == GLUT_KEY_RIGHT) {
        objectFrame.RotateWorld(m3dDegToRad(5), 0.0f, 1.0f, 0.0f);
    }
    
    glutPostRedisplay();
}

//根据空格次数。切换不同的 窗口名称
void KeyPressFunc(unsigned char key, int x, int y)
{
    if (key == 32) {
        nStep ++;
        if (nStep > 6) {
            nStep = 0;
        }
    }
    
    switch (nStep) {
        case 0:
            glutSetWindowTitle("GL_POINTS");
            break;
        case 1:
            glutSetWindowTitle("GL_LINES");
            break;
        case 2:
            glutSetWindowTitle("GL_LINE_STRIP");
            break;
        case 3:
            glutSetWindowTitle("GL_LINE_LOOP");
            break;
        case 4:
            glutSetWindowTitle("GL_TRIANGLES");
            break;
        case 5:
            glutSetWindowTitle("GL_TRIANGLE_STRIP");
            break;
        case 6:
            glutSetWindowTitle("GL_TRIANGLE_FAN");
            break;
    }
    glutPostRedisplay();
}

int main(int argc,char *argv[])
{

    //初始化GLUT库,这个函数只是传说命令参数并且初始化glut库
    glutInit(&argc, argv);
    
    glutInitDisplayMode(GLUT_DOUBLE|GLUT_RGBA|GLUT_DEPTH|GLUT_STENCIL);
    
    //GLUT窗口大小、窗口标题
    glutInitWindowSize(800, 600);
    glutCreateWindow("GL_POINTS");
    

    //注册重塑函数
    glutReshapeFunc(changeSize);
    //点击空格时，调用的函数
    glutKeyboardFunc(KeyPressFunc);
    // 特殊键位函数
    glutSpecialFunc(SpecialKeys);
    //注册显示函数
    glutDisplayFunc(RenderScene);

    /*
     初始化一个GLEW库,确保OpenGL API对程序完全可用。
     在试图做任何渲染之前，要检查确定驱动程序的初始化过程中没有任何问题
     */
    GLenum status = glewInit();
    if (GLEW_OK != status) {
        
        printf("GLEW Error:%s\n",glewGetErrorString(status));
        return 1;
        
    }
    
    //设置我们的渲染环境
    setupRC();
    glutMainLoop();
 
    return  0;
    
}
