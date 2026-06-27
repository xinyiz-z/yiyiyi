#include<iostream>
#include<cstdio>
using namespace std;
void OBST(float *a,float *b,int n,float **m,int **s,float **w);

int main()
{
    float a[100];
    float b[100];
    int n;
    float **m;
    int **s;
    float **w;
    cout << "请输入节点数目 n：";
    cin >> n;
    cout << "请输入节点查找成功的概率(n个)：";
	for (int i = 1; i <= n; i++)
    cin >> b[i];
	cout << "请输入节点查找失败的概率(n+1个)：";
	for (int i = 0; i <= n; i++)
    cin >> a[i];
    m = new float* [n + 2];
    s = new int* [n + 2];
    w = new float* [n + 2];
    for (int e= 0; e < n + 2; e++)
    {
        m[e] = new float[n + 1];
        s[e] = new int[n + 1];
        w[e] = new float[n + 1];
    }
    // 构造最优二叉搜索树
    OBST(a,b,n,m,s,w);
    cout<<m[1][n];
//    // 输出二叉树
//    printBintree(m, 1, n);
//    for (int e = 0; e < n + 2; e++)
//    {
//        for (int j = 0; j < n + 1; j++)
//        {
//            cout << w[e][j] << "\t";
//        }
//        cout << endl;
//    }
}

void OBST(float *a,float *b,int n,float **m,int **s,float **w)
{
    for (int i=0; i<=n; i++)
    {
        w[i+1][i]=a[i];
        m[i+1][i]=0;
        s[i+1][i]=0;
    }
    for(int r=0; r<n; r++)
    {
        for(int i=1; i<=n-r; i++)
        {
            int j=i+r,i1=s[i][j-1]>1?s[i][j-1]:i,j1=s[i+1][j]>i?s[i+1][j]:j;
            w[i][j]=w[i][j-1]+a[j]+b[j];
            m[i][j]=m[i][i1-1]+m[i1+1][j];
            s[i][j]=i1;
            for(int k=i1+1; k<=j1; k++)
            {
                int t=m[i][k-1]+m[k+1][j];
                if (t<=m[i][j])
                {
                    m[i][j]=t;
                    s[i][j]=k;
                }
            }
        m[i][j]+=w[i][j];
        }

    }
}

void printBintree(float** root, int i, int j)
{
    if (i < j)
    {
        int r = root[i][j];
        cout << "S" << r << "是根\n";
        if (root[i][r - 1] > 0)
            cout << "S" << r << "的左孩子是S" << root[i][r - 1] << endl;
        if (root[r + 1][j] > 0)
            cout << "S" << r << "的右孩子是S" << root[r + 1][j] << endl;
        printBintree(root, i, r - 1);
        printBintree(root, r + 1, j);
    }
}

