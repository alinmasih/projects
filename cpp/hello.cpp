#include <iostream>
using namespace std;

int main(){
    int n;
    cout<<"enter a num\n";
    cin>>n;
    int sum=0;
    for(int i =1;i<=n;i++){
        sum+=i;
    }
    cout<<sum;
    return 0;
}