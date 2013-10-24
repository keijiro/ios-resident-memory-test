# iOS における malloc の挙動について

iOS アプリ開発の現場においては、度々、メモリ消費量のことが話題にあげられます。しかし、アプリの「メモリ消費量」を正確に測定することは簡単ではありません。何をもって「メモリ消費量」とするか、その定義が明らかでないためです。

「メモリ消費量」を表す数値としてよく参考に挙げられるのが、Activity Monitor で取得できる "Real Memory Usage" の値や、[task_basic_info.resident_size](http://stackoverflow.com/questions/787160/programmatically-retrieve-memory-usage-on-iphone) の値です。

![Real Memory Usage](http://keijiro.github.io/ios-resident-memory-test/RealMemoryUsage.png)

ただ、これらの値は若干不可解な動きをすることがあります。malloc でメモリを確保すると、これらの値が上がっていくのはもちろんのことですが、free によってメモリを返却しても、これらの値が下がらないことがあるためです。

## テストプログラム

この挙動を詳しく観察するために、簡単なテストプログラムを作成しました。

![Test Program](http://keijiro.github.io/ios-resident-memory-test/TestProgram.png)

このテストプログラムには３つのボタンがあります。

- 大きなメモリブロックを確保する。
- 小さなメモリブロックを大量に確保する。
- メモリブロックを解放する。

「大きなメモリブロックを確保する」ボタンは、次のような処理で 16MB のメモリを確保します。

    for (int i = 0; i < 64; i++) {
        _pointerArray[i] = AllocateDirtyBlock(256 * 1024);
    }

「小さなメモリブロックを確保する」ボタンは、次のような処理で 8MB のメモリを確保します。

    for (int i = 0; i < 1024 * 1024; i++) {
        _pointerArray[i] = AllocateDirtyBlock(8);
    }

これらのボタンを押したときに生じる挙動を観察してみます。

### 大きなメモリブロックの場合

初期状態では 7MB 程度であったのが、ボタンを押すと 23MB にまで増えました。解放ボタンを押すと 11MB にまで減りました。

![Large Block Allocation](http://keijiro.github.io/ios-resident-memory-test/LargeBlockAllocation.png)

完全に元には戻らないのが若干不思議ですが、分かりやすい結果と言えます。

### 小さなメモリブロックの場合

初期状態では 7MB 程度であったのが、ボタンを押すと 26MB にまで増えました。解放ボタンを押しても値は減少しません。

![Small Block Allocation](http://keijiro.github.io/ios-resident-memory-test/SmallBlockAllocation.png)

この後、ホームボタンを押してアプリを中断し、Facebook, Twitter, Safari, Gmail 等、適度にメモリを消費するアプリを立ち上げていったところ、resident memory は 11MB まで減りました。

![Small Block Allocation (2)](http://keijiro.github.io/ios-resident-memory-test/SmallBlockAllocation2.png)

## なぜ違いが出るのか

iOS は malloc 経由で確保されるメモリを **tiny**, **small**, **large** の３つ<sup>1</sup>の **zone** に分類して管理します。このうち large zone は、領域が解放されると即座に物理メモリをシステムに返却します。他の２つは、メモリプレッシャーが生じるまで解放しない傾向にあります。そのため、上のような挙動の違いが生じます。

これらの挙動の違いは、VM Tracker を使用することで、より詳しく観察できます。

 - 1. 過去の資料には "huge" という 4 つ目の zone が存在すると記されている場合もありますが、これは [magazine allocator](http://www.opensource.apple.com/source/Libc/Libc-825.40.1/gen/magazine_malloc.c) への移行の際に廃止されています。恐らく現状の iOS でも使用されていないでしょう。
