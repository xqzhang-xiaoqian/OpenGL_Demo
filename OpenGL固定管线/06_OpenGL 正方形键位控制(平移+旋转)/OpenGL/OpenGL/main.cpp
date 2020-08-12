//
//  main.cpp
//  OpenGL
//
//  Created by 张喜千 on 2020/8/2.
//  Copyright © 2020 张喜千. All rights reserved.
//

// 着色器管理器（shader Mananger）类
#include "GLShaderManager.h"
// 包含了大部分GLTool中类似C语言的独立函数
#include "GLTools.h"
// GLUT
#include <GLUT/GLUT.h>

//定义一个，着色管理器
GLShaderManager shaderManager;
//简单的批次容器，是GLTools的一个简单的容器类。
GLBatch triangleBatch;

//blockSize 顶点到原心的距离
GLfloat blockSize = 0.1f;

//正方形四个点的坐标
GLfloat vVerts[] = {
    -blockSize, -blockSize, 0.0f,
    blockSize, -blockSize, 0.0f,
    blockSize, blockSize, 0.0f,
    -blockSize, blockSize, 0.0f,
};

GLfloat xPos = 0.0f;
GLfloat yPos = 0.0f;

void RenderScene(void)
{

    //1清除缓存区
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    
    GLfloat vRed[] = {1.0f, 0.5f, 0.0f, 1.0f};
    
    //定义矩阵
    M3DMatrix44f mFinalTransform, mTransformMatrix, mRotationMatrix;
    
    //平移矩阵
    m3dTranslationMatrix44(mTransformMatrix, xPos, yPos, 0.0f);
    
    //每次旋转5度
    static float yRot = 0.0f;
    yRot += 5.0f;
    m3dRotationMatrix44(mRotationMatrix, yRot, 0.0f, 0.0f, 1.0f);
    
    //综合 -- 矩阵叉乘
    m3dMatrixMultiply44(mFinalTransform, mTransformMatrix, mRotationMatrix);
    
    //mvp -- 矩阵叉乘
    //让每一个顶点都应该平移 -- 固定管线
    //当单元着色器不够用时，使用平面着色器
    //参数1：存储着色器类型
    //参数2：使用什么矩阵变换
    //参数3：颜色
    shaderManager.UseStockShader(GLT_SHADER_FLAT, mFinalTransform, vRed);
    
    triangleBatch.Draw();
    glutSwapBuffers();
}

void setupRC()
{
    //1.设置一个背景颜色
    glClearColor(0.3f, 0.3f, 0.3f, 1.0f);
    
    shaderManager.InitializeStockShaders();
    
    //
    triangleBatch.Begin(GL_TRIANGLE_FAN, 4);
    triangleBatch.CopyVertexData3f(vVerts);
    triangleBatch.End();
    
}
//移动顶点 -> 修改每一个顶点相对位置
//使用矩阵方式，不需要修改每个顶点，只需要记录移动步长，碰撞检测
void SpecialKeys(int key, int x, int y)
{
    GLfloat stepSize = 0.025f;
    if (key == GLUT_KEY_UP) {
        yPos += stepSize;
    }
    if (key == GLUT_KEY_DOWN) {
        yPos -= stepSize;
    }
    if (key == GLUT_KEY_LEFT) {
        xPos -= stepSize;
    }
    if (key == GLUT_KEY_RIGHT) {
        xPos += stepSize;
    }
    
    //碰撞检测，xPos是平移距离，即移动量
    if (xPos < -1.0f + blockSize) {
        xPos = -1.0f + blockSize;
    }
    if (xPos > (1.0f + blockSize)) {
        xPos = 1.0f - blockSize;
    }
    if (yPos < (-1.0f + blockSize)) {
        yPos = -1.0f + blockSize;
    }
    if (yPos > (1.0f - blockSize)) {
        yPos = 1.0f - blockSize;
    }
    glutPostRedisplay();
}

//在窗口大小改变时，接收新的宽度&高度。
void changeSize(int w,int h)
{
    glViewport(0, 0, w, h);
}

int main(int argc,char *argv[])
{

    //初始化GLUT库,这个函数只是传说命令参数并且初始化glut库
    glutInit(&argc, argv);
    
    
    glutInitDisplayMode(GLUT_DOUBLE|GLUT_RGBA|GLUT_DEPTH|GLUT_STENCIL);
    
    //GLUT窗口大小、窗口标题
    glutInitWindowSize(800, 600);
    glutCreateWindow("Triangle");
    
  
    //注册重塑函数
    glutReshapeFunc(changeSize);
    // 注册特殊键位函数
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
