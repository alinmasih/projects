#include <iostream>
using namespace std;

int main(){
    int n;
    cout<<"enter a num\n";
    cin>>n;
    int fact=0;
    for(int i=2; i<=n;i++){
        if(n%i==0){
            cout<<"the fact is "<<i<<"\n";
        }
    }

    return 0;
}