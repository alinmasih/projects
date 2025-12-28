#include <iostream>
using namespace std;

int main(){
    int n;
    cout<<"enter a num\n";
    cin>>n;
    int fact=1;

    if(n==0 || n==1){
        fact=1;
    }
    else{
      for(int i=n; i>1;i--){
        fact*=i;
    }  
    }
    
    cout<<"the fact is "<<fact;

    return 0;
}