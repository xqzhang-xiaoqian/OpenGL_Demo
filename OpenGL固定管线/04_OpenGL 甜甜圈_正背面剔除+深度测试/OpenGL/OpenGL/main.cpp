//
//  main.cpp
//  OpenGL
//
//  Created by 张喜千 on 2020/8/2.
//  Copyright © 2020 张喜千. All rights reserved.
//

//演示了OpenGL背面剔除，深度测试，和多边形模式
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

//设置角色帧，作为相机
GLFrame            viewFrame;
//使用GLFrustum类来设置透视投影
GLFrustum           viewFrustum;
GLTriangleBatch     torusBatch;
GLMatrixStack       modelViewMatrix;
GLMatrixStack       projectionMatrix;
GLGeometryTransform transformPipleline;
GLShaderManager     shaderManager;

//标记：正背面剔除 、 深度测试
int iCull = 0;
int iDepth = 0;

//右键菜单栏选项
void ProcessMenu(int value)
{
    switch (value) {
        case 1:
            iDepth = !iDepth;
            break;
        case 2:
            iCull = !iCull;
            break;
        case 3:
            glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
            break;
        case 4:
            glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
            break;
        case 5:
            glPolygonMode(GL_FRONT_AND_BACK, GL_POINT);
            break;
    }
    glutPostRedisplay();
}

//召唤场景
void RenderScene(void)
{
    //清除窗口和深度缓冲区
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    //根据设置iCull标记来判断是否开启背面剔除
    if (iCull) {
        glEnable(GL_CULL_FACE);
    } else {
        glDisable(GL_CULL_FACE);
    }
    
    //根据设置 iDepth 标记来判断是否开启深度测试
    if (iDepth) {
        glEnable(GL_DEPTH_TEST);
    } else {
        glDisable(GL_DEPTH_TEST);
    }
    
    //把摄像机矩阵压入模型矩阵中
    modelViewMatrix.PushMatrix(viewFrame);
    
    GLfloat vRed[] = {1.0f ,0.0f, 0.0f, 1.0f};
    
    //使用默认光源着色器
    shaderManager.UseStockShader(GLT_SHADER_DEFAULT_LIGHT, transformPipleline.GetModelViewMatrix(), transformPipleline.GetProjectionMatrix(), vRed);
    
    //绘制
    torusBatch.Draw();
    
    //出栈
    modelViewMatrix.PopMatrix();
    
    glutSwapBuffers();
    
}

void setupRC()
{
    // 设置背景颜色
    glClearColor(0.3f, 0.3f, 0.3f, 1.0f);
    
    //初始化着色器
    shaderManager.InitializeStockShaders();
    
    //将相机向后移动7个单元：肉眼到物体之间的距离
    viewFrame.MoveForward(7.0);
    
    //创建甜甜圈
    gltMakeTorus(torusBatch, 1.0f, 0.3f, 53, 26);
    
    glPointSize(4.0f);
    
}
//键位设置，通过不同的键位对其进行设置
// 控制Camera的移动，从而改变视口
void SpecialKeys(int key, int x, int y)
{
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
    
    //重新刷新
    glutPostRedisplay();
}

void changeSize(int w,int h)
{
    //1.防止h变为0
    if (h == 0) {
        h = 1;
    }
    
    //设置视口窗口尺寸
    glViewport(0, 0, w, h);
    
    // setPerspective 函数的参数是一个从顶点方向看去的视场角度（用角度值表示）
    //设置透视模式，初始化其矩阵
    viewFrustum.SetPerspective(35.0f, float(w)/float(h), 1.0f, 100.0f);
    
    //把透视矩阵加载到透视矩阵对阵中
    projectionMatrix.LoadMatrix(viewFrustum.GetProjectionMatrix());
    
    //初始化渲染管线
    transformPipleline.SetMatrixStacks(modelViewMatrix, projectionMatrix);
}

int main(int argc,char *argv[])
{

    gltSetWorkingDirectory(argv[0]);
    //初始化GLUT库,这个函数只是传说命令参数并且初始化glut库
    glutInit(&argc, argv);
    
    glutInitDisplayMode(GLUT_DOUBLE|GLUT_RGBA|GLUT_DEPTH|GLUT_STENCIL);
    
    //GLUT窗口大小、窗口标题
    glutInitWindowSize(800, 600);
    glutCreateWindow("Geometry Test Program");
    //注册重塑函数
    glutReshapeFunc(changeSize);
    //注册特殊键位
    glutSpecialFunc(SpecialKeys);
    //注册显示函数
    glutDisplayFunc(RenderScene);

    //创建Menu
    glutCreateMenu(ProcessMenu);
    glutAddMenuEntry("Toggle depth test", 1);
    glutAddMenuEntry("Toglle cull backface", 2);
    glutAddMenuEntry("Set Fill Mode", 3);
    glutAddMenuEntry("Set Line Mode", 4);
    glutAddMenuEntry("Set Point Mode", 5);
    
    glutAttachMenu(GLUT_RIGHT_BUTTON);
    
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
