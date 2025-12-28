#include <iostream>
using namespace std;

int main(){
    int n;
    cout<<"enter the size of array"<<endl;
    cin>>n;
    int a[n];
    for(int i=0; i<n; i++){
        cin>>a[i];
    }

    int max =0,temp=0;

    for(int i =0;i<n-1;i++){
        if(a[i]<a[i+1]){
            temp=a[i];
            a[i]=a[i+1];
            a[i+1]=temp;
        }
    }

    cout<<"min is "<<a[n-1];

    


    return 0;
}