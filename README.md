# iOS における malloc の挙動について

この文書は、iOS において malloc / free を使用した場合の、メモリ消費のあり方について考察するものです。いわば、古き良き libc 経由でのメモリ管理のアプローチについて触れるものであり、Cocoa 経由でのメモリ管理についてはまた異なったアプローチがあるので注意してください。

## メモリ消費量の不可解な変動

iOS アプリ開発の現場においては、度々、メモリ消費量のことが話題にあげられます。しかし、アプリの「メモリ消費量」を正確に測定することは簡単ではありません。何をもって「メモリ消費量」とするか、その定義が明らかでないためです。

「メモリ消費量」を表す数値としてよく参考に挙げられるのが、Activity Monitor で取得できる "Real Memory Usage" の値や、[task_basic_info.resident_size](http://stackoverflow.com/questions/787160/programmatically-retrieve-memory-usage-on-iphone) の値です。

![Real Memory Usage](http://keijiro.github.io/ios-resident-memory-test/RealMemoryUsage.png)

ただ、これらの値は若干不可解な動きをすることがあります。malloc でメモリを確保すると、これらの値が上がっていくのはもちろんのことですが、free によってメモリを返却しても、これらの値が下がらないことがあるのです。

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

この後、ホームボタンを押してアプリを中断し、Facebook, Twitter, Safari, Gmail 等、適度にメモリを消費するアプリを立ち上げていったところ、Real Mem は 11MB まで減りました。

![Small Block Allocation (2)](http://keijiro.github.io/ios-resident-memory-test/SmallBlockAllocation2.png)

## なぜ違いが出るのか

iOS は malloc 経由で確保されるメモリを **tiny**, **small**, **large** の３つ<sup>1</sup>の **zone** に分類して管理します。このうち large zone は、領域が解放されると即座に物理メモリをシステムに返却します。他の２つは、メモリプレッシャーが生じるまで解放しない傾向にあります。そのため、上のような挙動の違いが生じます。

これらの挙動の違いは、VM Tracker を使用することで、より詳しく観察できます。

> <sup>1</sup> 過去の資料には "huge" という 4 つ目の zone が存在すると記されている場合もありますが、これは [magazine allocator](http://www.opensource.apple.com/source/Libc/Libc-825.40.1/gen/magazine_malloc.c) への移行の際に廃止されています。恐らく現状の iOS でも使用されていないでしょう。

## VM Tracker で詳しく観察する

Instruments の Activity Monitor テンプレートはシステムの状態を大まかに観察できますが、メモリの状態を詳細に分析することはできません。詳細な分析には Allocations テンプレートが適しています。このテンプレートに含まれる **VM Tracker** は、仮想メモリの状態を詳細に観察できる非常に強力なツールです。

![VM Tracker](http://keijiro.github.io/ios-resident-memory-test/VMTracker.png)

まず、大きなメモリブロックの場合を観察してみました。

![VM Tracker - Large Block](http://keijiro.github.io/ios-resident-memory-test/VMTrackerLargeBlock.png)

このグラフでは、Dirty Size （割り当てられた物理メモリのうち、実際に使用されている領域の総量）と Resident Size がほぼ連動して動いています。両方とも解放後に値が減少しています（元の値にまでは戻りませんが、それはここでは無視してください<sup>2</sup>）。

次に、小さなメモリブロックの場合を観察してみました。

![VM Tracker - Small Block](http://keijiro.github.io/ios-resident-memory-test/VMTrackerSmallBlock.png)

Activity Monitor で確認したときのように、Resident Size が元に戻らない現象が発生しています。ただし、Dirty Size の方は適切に減少していることが分かります。つまりこれは「メモリは正しく解放されているが、Malloc がリソースの返却を保留している」という状態を示しています。

VM Tracker の詳細ビューを使って、tiny zone や small zone が確保している領域に注目してみましょう。

![VM Tracker - Small Block (2)](http://keijiro.github.io/ios-resident-memory-test/VMTrackerSmallBlock2.png)

これらの領域はメモリ確保に伴い Resident Size と Dirty Size が増えていきますが、解放の際は Dirty Size だけが減少しています。他のアプリを起動して適度にメモリプレッシャーを与えると、Resident Size も適切なサイズにまで縮小されました。

> <sup>2</sup> 使用メモリ領域の拡大に伴い、Instruments が使用するメモリ領域も拡大していきます。この領域は一旦拡大すると縮小することがないため、どうしても元通りにはなりません。

## まとめ

iOS アプリにおけるメモリ消費量を観察する目的で Resident Size を用いることがありますが、この値には malloc が返却を保留している分も含めて計上されます。そのため、リアルタイムな観察を行うには適していません。

他方で、Resident Size はメモリ不足時にプロセスを破棄する判断基準として用いられるため<sup>3</sup>、この値がある種の重要性を持つことは確かです。

以上の考察をまとめると、次のように考えるのが良いのかもしれません。

- Resident Size はアプリのメモリ消費の**ピーク量**を把握するには適切な指標である。
- アプリ内でもリアルタイムなメモリ使用量を把握する目的で Resident Size を観察するのは適切でない。
- ある瞬間におけるメモリ消費の実態を把握するには Allocations と VM Tracker の併用が欠かせない。

> <sup>3</sup> 実際の iOS の仕様を知ることはできませんが、参考資料に挙げる XNU のソースコードでは task_basic_info.resident_size を使用していることが分かります。

## 参考資料

- [Memory Usage Performance Guidelines](https://developer.apple.com/library/IOs/documentation/Performance/Conceptual/ManagingMemory/ManagingMemory.html)

Apple の公式なガイドラインです。

- [A look at how malloc works on the Mac](http://www.cocoawithlove.com/2010/05/look-at-how-malloc-works-on-mac.html)

Mac OS X における malloc の挙動を解説しています。そのほとんどの記述は iOS でも参考になります。

- [magazine_malloc.c](http://www.opensource.apple.com/source/Libc/Libc-825.40.1/gen/magazine_malloc.c)

Mac OS X で使用されている Libc 内のメモリアロケーターの実装です。現状の iOS でもこれに近いものが使用されていると推測されます。

- [kern_memorystatus.c](http://www.opensource.apple.com/source/xnu/xnu-2050.48.11/bsd/kern/kern_memorystatus.c)

Mac OS X のカーネル (XNU) に含まれるメモリ消費量分析のソースコードです。メモリ不足時にプロセスを停止させるための機構 (Jetsam) が実装されています。iOS で用いられている同様の仕組みは、このコードに近いものであると推測されます。

- [Mac OS X and iOS Internals: To the Apple's Core](http://www.newosxbook.com/)

Mac OS X と iOS のカーネル実装について解説した書籍です。
