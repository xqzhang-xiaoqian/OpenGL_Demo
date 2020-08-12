//
//  main.cpp
//  OpenGL
//
//  Created by 张喜千 on 2020/8/2.
//  Copyright © 2020 张喜千. All rights reserved.
//
// 演示OpenGL 甜甜圈  正背面剔除，深度测试和多边形模式
#include "GLTools.h"
#include "GLMatrixStack.h"
#include "GLFrame.h"
#include "GLFrustum.h"
#include "GLGeometryTransform.h"

#include <math.h>
#ifdef __APPLE__
#include <glut/glut.h>
#else
#define FREEGLUT_STATIC
#include <GL/glut.h>
#endif

/*
GLMatrixStack 变化管线使用矩阵推栈

GLMatrixStack 构造函数允许指定堆栈的最大深度、默认的堆栈深度为64.这个矩阵堆在初始化时已经在堆栈中包含了单位矩阵。
GLMatrixStack:GLMatrixStack(int iStackDepth = 64)

// 通过调用顶部载入这个单位矩阵
void GLMatrixStack::LoadIndentiy(void)

// 在推栈顶部载入任何矩阵
void GLMatrixStack::LoadMatrix(const M3DMatrix44f m);
*/


//设置角色帧，作为相机
GLFrame     viewFrame;
//使用GLFrustum类来设置透视投影
GLFrustum     viewFrustum;
GLTriangleBatch     torusBatch;
GLMatrixStack       modelViewMatrix;  //记录变化矩阵，先加载单元矩阵，再
GLMatrixStack       projectionMatrix;  //记录投影矩阵
GLGeometryTransform transformPipeline;
GLShaderManager     shaderManager;

void RenderScene(void)
{
    //1.清除窗口和深度缓冲区
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    //2.把摄像机矩阵压入模型矩阵中
    modelViewMatrix.PushMatrix(viewFrame);
    
    //3.设置绘图颜色
    GLfloat vRed[] = {1.0f, 0.0f, 0.0f, 1.0f};
    
    //4.
    //使用平面着色器
    //参数1：平面着色器
    //参数2：模型视图投影矩阵
    //参数3：颜色
//    shaderManager.UseStockShader(GLT_SHADER_FLAT, transformPipeline.GetModelViewProjectionMatrix(), vRed);
    
    //使用默认光源着色器
    //通过光源、阴影效果跟提现立体效果
    //参数1：GLT_SHADER_DEFAULT_LIGHT 默认光源着色器
    //参数2：模型视图矩阵
    //参数3：投影矩阵
    //参数4：基本颜色值
    shaderManager.UseStockShader(GLT_SHADER_DEFAULT_LIGHT, transformPipeline.GetModelViewMatrix(), transformPipeline.GetProjectionMatrix(), vRed);
    
    //5.绘制
    torusBatch.Draw();
    
    //6.出栈 绘制完成恢复
    modelViewMatrix.PopMatrix();
    
    //7.交换缓存区
    glutSwapBuffers();
}

void setupRC()
{
    //1.设置背景颜色
    glClearColor(0.3f, 0.3f, 0.3f, 1.0f);
    
    //2.初始化着色器管理器
    shaderManager.InitializeStockShaders();
    
    //3.将相机向后移动7个单元：肉眼到物体之间的距离
    viewFrame.MoveForward(7.0);
    
    //4.创建一个甜甜圈
    //void gltMakeTorus(GLTriangleBatch& torusBatch, GLfloat majorRadius, GLfloat minorRadius, GLint numMajor, GLint numMinor);
    //参数1：GLTriangleBatch 容器帮助类
    //参数2：外边缘半径
    //参数3：内边缘半径
    //参数4、5：主半径和从半径的细分单元数量
    gltMakeTorus(torusBatch, 1.0f, 0.3f, 52, 26);
    
    //5.点的大小(方便点填充时，肉眼观察)
    glPointSize(4.0f);
}

void SpecialKeys(int key, int x, int y)
{
    //1.判断方向,根据方向调整观察者位置
    if (key == GLUT_KEY_UP) {
        viewFrame.RotateWorld(m3dDegToRad(-5), 1.0f, 0.0f, 0.0f);
    }
    if (key == GLUT_KEY_DOWN) {
        viewFrame.RotateWorld(m3dDegToRad(5), 1.0f, 0.0f, 0.0f);
    }
    if (key == GLUT_KEY_LEFT) {
        viewFrame.RotateWorld(m3dDegToRad(-5), 0.0f, 1.0f, 0.0f);
    }
    if (key == GLUT_KEY_RIGHT) {
        viewFrame.RotateWorld(m3dDegToRad(5), 0.0f, 1.0f, 0.0f);
    }
    
    //2.重新刷新
    glutPostRedisplay();
}

 //在窗口大小改变时，接收新的宽度&高度。
void changeSize(int w,int h)
{
    //1.防止h变为0
    if (h == 0) {
        h = 1;
    }
    
    //2.设置视口窗口尺寸
    glViewport(0, 0, w, h);
    
    //3.setPerspective 函数的参数是一个从顶点方向看去的视场角度（用角度值表示）
    //设置透视模式，初始化其透视矩阵 参数1：打开的度数   2:纵横比    3.4：近远距离
    viewFrustum.SetPerspective(35.0f, float(w)/float(h), 1.0f, 100.0f);
    
    //4.把透视矩阵加载到透视矩阵对阵中. 拿到投影矩阵，存在projectionMatrix中
    projectionMatrix.LoadMatrix(viewFrustum.GetProjectionMatrix());
    
    //5.初始化渲染管线
    //设置变换管线以使用两个矩阵堆栈(功能，快速去矩阵相乘)
    //变化管道： 快速去矩阵相乘  便利
    transformPipeline.SetMatrixStacks(modelViewMatrix, projectionMatrix);
}





int main(int argc,char *argv[])
{

    gltSetWorkingDirectory(argv[0]);
    
    //初始化GLUT库,这个函数只是传说命令参数并且初始化glut库
    glutInit(&argc, argv);
    
    /*
     初始化双缓冲窗口，其中标志GLUT_DOUBLE、GLUT_RGBA、GLUT_DEPTH、GLUT_STENCIL分别指
     双缓冲窗口、RGBA颜色模式、深度测试、模板缓冲区
     
     --GLUT_DOUBLE`：双缓存窗口，是指绘图命令实际上是离屏缓存区执行的，然后迅速转换成窗口视图，这种方式，经常用来生成动画效果；
     --GLUT_DEPTH`：标志将一个深度缓存区分配为显示的一部分，因此我们能够执行深度测试；
     --GLUT_STENCIL`：确保我们也会有一个可用的模板缓存区。
     深度、模板测试后面会细致讲到
     */
    glutInitDisplayMode(GLUT_DOUBLE|GLUT_RGBA|GLUT_DEPTH|GLUT_STENCIL);
    
    //GLUT窗口大小、窗口标题
    glutInitWindowSize(800, 600);
    glutCreateWindow("Geometry Test Program");
    
    /*
     GLUT 内部运行一个本地消息循环，拦截适当的消息。然后调用我们不同时间注册的回调函数。我们一共注册2个回调函数：
     1）为窗口改变大小而设置的一个回调函数
     2）包含OpenGL 渲染的回调函数
     */
    //注册重塑函数
    glutReshapeFunc(changeSize);
    //特殊键位
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
