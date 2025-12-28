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
    int pos=0, neg=0;
    for(int i=0; i<n; i++){
        if(a[i]<0) neg++;
        else if( a[i]>0) pos++;
        else;
    }
    
    cout<<"the pos are "<<pos<<endl;
    cout<<"the neg are"<<neg<<endl;


    return 0;
}