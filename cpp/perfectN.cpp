#include <iostream>
using namespace std;

int main(){
    int n;
    cout<<"enter a num\n";
    cin>>n;
    int fctr=0;
    for(int i=1; i<n;i++){
        if(n%i==0){
            fctr+=i;
        }
    }
    if(fctr==n){
        cout<<"it is perfect\n";
    }
    else cout<<"not perfect\n";

    return 0;
}