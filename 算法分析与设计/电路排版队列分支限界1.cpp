#include <iostream>
#include <fstream>
using namespace std;
ifstream fin("D:\\Desktop\\111.txt");

template<class Type>
class Graph;

template<class T>
class MinHeap
{
	template<class Type>
	friend class Graph;
	public:
		MinHeap(int maxheapsize = 10);
		~MinHeap(){delete []heap;}

		int Size() const{return currentsize;}
		T Max(){if(currentsize) return heap[1];}

		MinHeap<T>& Insert(const T& x);
		MinHeap<T>& DeleteMin(T &x);

		void Initialize(T x[], int size, int ArraySize);
		void Deactivate();
		void output(T a[],int n);
	private:
		int currentsize, maxsize;
		T *heap;
};

template <class T>
void MinHeap<T>::output(T a[],int n)
{
	for(int i = 1; i <= n; i++)
	cout << a[i] << " ";
	cout << endl;
}

template <class T>
MinHeap<T>::MinHeap(int maxheapsize)
{
	maxsize = maxheapsize;
	heap = new T[maxsize + 1];
	currentsize = 0;
}

template<class T>
MinHeap<T>& MinHeap<T>::Insert(const T& x)
{
	if(currentsize == maxsize)
	{
		return *this;
	}
	int i = ++currentsize;
	while(i != 1 && x < heap[i/2])
	{
		heap[i] = heap[i/2];
		i /= 2;
	}

	heap[i] = x;
	return *this;
}

template<class T>
MinHeap<T>& MinHeap<T>::DeleteMin(T& x)
{
	if(currentsize == 0)
	{
		cout<<"Empty heap!"<<endl;
		return *this;
	}

	x = heap[1];

	T y = heap[currentsize--];
	int i = 1, ci = 2;
	while(ci <= currentsize)
	{
		if(ci < currentsize && heap[ci] > heap[ci + 1])
		{
			ci++;
		}

		if(y <= heap[ci])
		{
			break;
		}
		heap[i] = heap[ci];
		i = ci;
		ci *= 2;
	}

	heap[i] = y;
	return *this;
}

template<class T>
void MinHeap<T>::Initialize(T x[], int size, int ArraySize)
{
	delete []heap;
	heap = x;
	currentsize = size;
	maxsize = ArraySize;

	for(int i = currentsize / 2; i >= 1; i--)
	{
		T y = heap[i];
		int c = 2 * i;
		while(c <= currentsize)
		{
			if(c < currentsize && heap[c] > heap[c + 1])
				c++;
			if(y <= heap[c])
				break;
			heap[c / 2] = heap[c];
			c *= 2;
		}
		heap[c / 2] = y;
	}
}

template<class T>
void MinHeap<T>::Deactivate()
{
	heap = 0;
}

class BoardNode
{
	friend int BBArrangement(int **,int,int,int *&);
	public:
		operator int() const
		{
			return cd;
		}
	private:
		int *x,			//x[1:n]记录电路板排列
			s,			//x[1:s]是当前节点所相应的部分排列
			cd,			//x[1:s]的密度
			*now;		//now[j]是x[1:s]所含连接块j中电路板数
};

int BBArrangement(int **B,int n,int m,int *&bestx);

int main()
{
	int m = 5,n = 8;
	int *bestx;
	cout<<"m="<<m<<",n="<<n<<endl;
	cout<<"N1={4,5,6},N2={2,3},N3={1,3},N4={3,6},N5={7,8}"<<endl;
	cout<<"二维数组B如下："<<endl;
	int **B = new int*[n+1];
	for(int i=1; i<=n; i++)
	{
		B[i] = new int[m+1];
	}
	for(int i=1; i<=n; i++)
	{
		for(int j=1; j<=m ;j++)
		{
			fin>>B[i][j];
			cout<<B[i][j]<<" ";
		}
		cout<<endl;
	}
	cout<<"宋茂玲"<<endl;
	cout<<"当前最优密度为:"<<BBArrangement(B,n,m,bestx)<<endl;
	cout<<"最优排列为："<<endl;
	for(int i=1; i<=n; i++)
	{
		cout<<bestx[i]<<" ";
	}
	cout<<endl;

	for(int i=1; i<=n; i++)
	{
		delete[] B[i];
	}
	delete[] B;

	return 0;
}
//解电路板排列问题的优先队列式分支限界法
int BBArrangement(int **B,int n,int m,int *&bestx)
{
	MinHeap<BoardNode> H(1000);//活节点最小堆
	BoardNode E;
	E.x = new int[n+1];
	E.s = 0;
	E.cd = 0;

	E.now = new int[m+1];
	int *total = new int[m+1];
	for(int i=1; i<=m; i++)
	{
		total[i] = 0;
		E.now[i] = 0;
	}
	for(int i=1; i<=n; i++)
	{
		E.x[i] = i;//初始排列为1,2,3……n
		for(int j=1;j<=m;j++)
		{
			total[j] += B[i][j];//连接块中电路板数
		}
	}

	int bestd = m + 1;
	bestx = 0;
	do//节点扩展
	{
		if(E.s == n-1)//仅一个儿子节点
		{
			int ld  = 0;//最后一块电路板的密度
			for(int j=1; j<=m; j++)
			{
				ld += B[E.x[n]][j];
			}
			if(ld<bestd)//密度更小的电路排列
			{
				delete[] bestx;
				bestx = E.x;
				bestd = max(ld,E.cd);
			}
			else
			{
				delete []E.x;
			}
			delete []E.now;
		}
		else//产生当前扩展节点的所有儿子节点
		{
			for(int i=E.s+1;i<=n;i++)
			{
				BoardNode N;
				N.now = new int[m+1];
				for(int j=1; j<=m; j++)
				{
					//新插入的电路板
					N.now[j] = E.now[j] + B[E.x[i]][j];
				}
				int ld = 0;//新插入的电路板密度
				for(int j=1; j<=m; j++)
				{
					if(N.now[j]>0 && total[j]!=N.now[j])
					{
						ld++;
					}
				}
				N.cd = max(ld,E.cd);
				if(N.cd<bestd)//可能产生更好的叶子节点
				{
					N.x = new int[n+1];
					N.s = E.s + 1;
					for(int j=1;j<=n;j++)
					{
						N.x[j] = E.x[j];
					}
					N.x[N.s] = E.x[i];
					N.x[i] = E.x[N.s];
					H.Insert(N);
				}
				else
				{
					delete []N.now;
				}
			}
			delete []E.x;
		}//完成当前节点扩展
		if(H.Size() == 0)
		{
			return bestd;//无扩展节点
		}
		H.DeleteMin(E);
	}while(E.cd<bestd);
	//释放做小堆中所有节点
	do
	{
		delete []E.x;
		delete []E.now;
		if(H.Size() == 0)
		{
			break;
		}
		H.DeleteMin(E);
	}while(true);
	return bestd;
}
