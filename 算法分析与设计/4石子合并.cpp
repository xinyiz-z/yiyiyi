#include<iostream>
#include<fstream>
#include<sstream>
using namespace std;
int su[256];

int getsum(int i,int j,int n){
	if(i+j<n) return su[i+j]-su[i-1];
	else return (su[n]-su[i-1])+(su[j-(n-i)]);
}


int DeMin(int *a,int n,int **m,int **s)
{
	for(int i=1;i<=n;i++) m[i][0]=0;
	for(int j=1;j<=n-1;j++)
	  for(int i=1;i<=n;i++){//i,j互换位置，按照j=0,j=1的顺序对矩阵进行填值
	  	int k=j-1;
		m[i][j]=m[i][k]+m[(i+k)%n+1][0]+getsum(i,j,n);
		s[i][j]=k;
	  	for(k=j-2;k>=0;k--){
	  		int t=m[i][k]+m[(i+k)%n+1][j-k-1]+getsum(i,j,n);
	  		if(t<m[i][j]){m[i][j]=t;s[i][j]=k;}
		}
	  }
}

int DeMax(int *a,int n,int **m,int **s)
{
	for(int i=1;i<=n;i++) m[i][0]=0;//只有一堆石子
	for(int j=1;j<=n-1;j++)
	  for(int i=1;i<=n;i++){//i,j互换位置，按照j=0,j=1的顺序对矩阵进行填值
	  	int k=j-1;
		m[i][j]=m[i][k]+m[(i+k)%n+1][0]+getsum(i,j,n);
		s[i][j]=k;
	  	for(k=j-2;k>=0;k--){
	  		int t=m[i][k]+m[(i+k)%n+1][j-k-1]+getsum(i,j,n);
	  		if(t>m[i][j]){m[i][j]=t;s[i][j]=k;}
		}
	  }
}

void Traceback(int **s,int i,int j,int n,ofstream &outfile){
	if(j==0) return;
	Traceback(s,i,s[i][j],n,outfile);
	Traceback(s,s[i][j]%n+1,j-s[i][j]-1,n,outfile);
	outfile<<"Add A"<<i<<","<<(i+s[i][j]-1)%n+1;
	outfile<<" and A"<<(i+s[i][j])%n+1<<","<<(i+j-1)%n+1<<endl;
}

int main(){
    ifstream cinfile;
    cinfile.open("input.txt",ios::in);
    int n;
	cinfile>>n;
	int Stonum[n+1];
	Stonum[0]=0;
	for(int i=1;i<=n;i++) cinfile>>Stonum[i];
	cinfile.close();

	int **SN=new int*[n+1]();
	int **TN=new int*[n+1]();
	for(int i=0;i<=n;i++){
		SN[i]=new int[n+1];
		TN[i]=new int[n+1];
	}
	for(int i=0;i<=n;i++)
	  for(int j=0;j<=n;j++){
	  	SN[i][j]=0;
	  	TN[i][j]=0;
	  }
	su[0]=0;
	for(int i=1;i<=n;i++) su[i]=su[i-1]+Stonum[i];

	ofstream outfile;
	outfile.open("output.txt",ios::out);
	DeMin(Stonum,n,SN,TN);
	int Min=SN[1][n-1],posimin=1;
	for(int i=2;i<=n;i++){
		if(Min>SN[i][n-1]){
		  Min=SN[i][n-1];
		  posimin=i;
	    }
	}
	outfile<<Min<<endl;
	outfile<<"具体合并方案："<<endl;
	Traceback(TN,posimin,n-1,n,outfile);

	DeMax(Stonum,n,SN,TN);
	int Max=SN[1][n-1],posimax=1;
	for(int i=2;i<=n;i++){
		if(Max<SN[i][n-1]){
		  Max=SN[i][n-1];
		  posimax=i;
	    }
	}
	outfile<<Max<<endl;
	outfile<<"具体合并方案："<<endl;
	Traceback(TN,posimax,n-1,n,outfile);

}
