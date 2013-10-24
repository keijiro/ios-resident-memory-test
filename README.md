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
