//
//  main.cpp
//  OpenGL
//
//  Created by 张喜千 on 2020/8/2.
//  Copyright © 2020 张喜千. All rights reserved.
//

#include "GLTools.h"
#include "GLMatrixStack.h"
#include "GLFrame.h"
#include "GLFrustum.h"
#include "GLGeometryTransform.h"
#include "GLBatch.h"
#include "StopWatch.h"

#include <math.h>
#ifdef __APPLE__
#include <glut/glut.h>
#else
#define FREEGLUT_STATIC
#include <GL/glut.h>
#endif



GLFrustum       viewFrustum;
GLShaderManager shaderManager;
GLTriangleBatch torusBatch;
GLGeometryTransform transformPipeline;


 //在窗口大小改变时，接收新的宽度&高度。
void changeSize(int w,int h)
{
    if (h == 0) {
        h = 1;
    }
    
    glViewport(0, 0, w, h);
    
    //设置透视投影
    viewFrustum.SetPerspective(35.0f, float(w)/float(h), 1.0f, 100.0f);
}

void RenderScene(void)
{
    //清除屏幕
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    //建立基于时间变化的动画
    static CStopWatch rotTimer;
    //当前时间 * 60s
    float yRot = rotTimer.GetElapsedSeconds() * 60.0f;
    
    //2.矩阵变量
    /*
     mTranslate：平移
     mRotate：旋转
     mModelview：模型视图
     mModelViewProjection：模型视图投影MVP
     */
    M3DMatrix44f mTranslate, mRotate, mModelview, mModelViewProjection;

    //创建一个4*4矩阵变量，将花托沿着Z轴负方向移动2.5个单位长度
    m3dTranslationMatrix44(mTranslate, 0.0f, 0.0f, -2.5f);
    
    //创建一个4*4矩阵变量，将花托沿着Y轴上渲染 yRot 度，yRot根据经过时间设置动画帧率
    m3dRotationMatrix44(mRotate, m3dDegToRad(yRot), 0.0f, 1.0f, 0.0f);
    
    //为mModerView 通过矩阵旋转矩阵、移动矩阵相乘，将结果添加到mModerView上
    m3dMatrixMultiply44(mModelview, mTranslate, mRotate);
    
    //将投影矩阵乘以模型视图矩阵，将变化结果通过矩阵乘法应用到mModelViewProjection矩阵上
    //注意顺序: 投影 * 模型 != 模型 * 投影
    m3dMatrixMultiply44(mModelViewProjection, viewFrustum.GetProjectionMatrix(), mModelview);
    
    //绘图颜色
    GLfloat vBlack[] = {0.0f, 0.0f, 0.0f, 1.0f};
    
    //通过平面着色器提交矩阵，和颜色
    shaderManager.UseStockShader(GLT_SHADER_FLAT, mModelViewProjection, vBlack);
    
    //开始绘图
    torusBatch.Draw();
    
    //交换缓冲区，并立即刷新
    glutSwapBuffers();
    glutPostRedisplay();
}

void setupRC()
{
    glClearColor(0.8f, 0.8f, 0.8f, 1.0f);
    shaderManager.InitializeStockShaders();
    glEnable(GL_DEPTH_TEST);
    
    //形成一个球
    gltMakeSphere(torusBatch, 0.4f, 10, 20);
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
    
}

int main(int argc,char *argv[])
{

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
    glutCreateWindow("ModelViewProjection Example");
    
    /*
     GLUT 内部运行一个本地消息循环，拦截适当的消息。然后调用我们不同时间注册的回调函数。我们一共注册2个回调函数：
     1）为窗口改变大小而设置的一个回调函数
     2）包含OpenGL 渲染的回调函数
     */
    //注册重塑函数
    glutReshapeFunc(changeSize);
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
