# 課題3-1：パッチパネルの機能拡張
* 学籍番号：33E16009
* 氏名：坂本昂輝

## 課題内容
パッチパネルに機能を追加せよ。パッチの追加と削除以外に、以下の機能をパッチパネルに追加すること。

* ポートのミラーリング
* パッチとポートミラーリングの一覧

それぞれ patch\_panel のサブコマンドとして実装すること。

## 解答
まず実装したコマンドの説明を行い、その後合わせて動作結果を示す。

### ポートのミラーリング

#### コマンド
ポートのミラーリング設定は下記のコマンドで行うものとする。dpid は仮想スイッチの id で、port\_mirrored はミラーリングによって監視されるポート番号、port\_mirroring は監視する側のポート番号である。

> cmirror [dpid] [port\_mirrored] [port\_mirroring]

このコマンドは、次のファイルに記述した。該当部分をその次に示す。

* [bin/patch\_panel](https://github.com/handai-trema/patch-panel-k-sakamoto3/blob/develop/bin/patch_panel)

```ruby
  desc 'Creates a mirror port'
  arg_name 'dpid port#1 port#2'
  command :cmirror do |c|
    c.desc 'Location to find socket files'
    c.flag [:S, :socket_dir], default_value: Trema::DEFAULT_SOCKET_DIR

    c.action do |_global_options, options, args|
      dpid = args[0].hex
      port1 = args[1].to_i
      port2 = args[2].to_i
      Trema.trema_process('PatchPanel', options[:socket_dir]).controller.
        create_mirror(dpid, port1, port2)
    end
  end
```

結果として、cmirror コマンドによって、[lib/patch\_panel](https://github.com/handai-trema/patch-panel-k-sakamoto3/blob/develop/lib/patch_panel.rb) で定義した create\_mirror メソッドに、引数 dpid、port1、port2 を渡してコントローラ側で処理を行う。


#### 呼び出し関数

* [lib/patch_panel.rb](https://github.com/handai-trema/patch-panel-k-sakamoto3/blob/develop/lib/patch_panel.rb)

```ruby
  def create_mirror(dpid, port_monitored, port_monitoring)
    add_mirror_entries dpid, port_monitored, port_monitoring
    @mirror[dpid] << [port_monitored, port_monitoring].sort
  end
```

cmirror コマンドによって、create\_mirror が呼び出される。まず、次に示す add\_mirror\_entries でミラーポートを設定し、どのポートがどのポートを監視しているのかを記録しておくために @mirror にその情報を格納しておく。


```ruby
  def add_mirror_entries(dpid, port_monitored_src, port_monitoring)
    port_monitored_dst = 0
    @patch[dpid].each do |port_a, port_b|
      if port_a == port_monitored_src then
        port_monitored_dst = port_b
        break
      elsif port_b == port_monitored_src then
        port_monitored_dst = port_a
        break
      end
    end
    if port_monitored_dst == 0 then
    else
      send_flow_mod_delete(dpid, match: Match.new(in_port: port_monitored_src))
      send_flow_mod_delete(dpid, match: Match.new(in_port: port_monitored_dst))
      send_flow_mod_add(dpid,
                        match: Match.new(in_port: port_monitored_src),
                        actions: [
                          SendOutPort.new(port_monitored_dst),
                          SendOutPort.new(port_monitoring)
                        ])
      send_flow_mod_add(dpid,
                        match: Match.new(in_port: port_monitored_dst),
                        actions: [
                          SendOutPort.new(port_monitored_src),
                          SendOutPort.new(port_monitoring)
                        ])
    end
  end

```

ミラーポートの設定部分である。ここで用いる変数とその意味を以下の表にまとめる。

| 変数名  | 意味  |
|:-------------: |:---------------|
| port\_monitored\_src      | ミラーリングで監視されるポート |
| port\_monitored\_dst      | ミラーリングで監視されるポートがパッチ接続している先のポート        |
| port\_monitoring | ミラーリングで監視する側のポート        |

これらの変数を用いて説明する。まず、port\_monitored\_dst を 0 に設定しておくことで、まだそもそもパッチが存在しない場合、もしくは port\monitored\_src にパッチが設定されていない場合には、後の == 0 の if 文で true となり、else 下の処理が無視される。

監視対象のポートにパッチが設定されているならば、監視対象のポートの接続先を調べ、そのポートの設定も変える必要がある。そのため、do ... end の繰り返しの中で接続先ポートを特定する。

その後、send\_flow\_mod\_delete で監視対象のポートの元の設定を消去し(send\_flow\_mod\_add で上書きされる仕様のため、delete は本来必要ない)、send\_flow\_mod\_add で新たに出力先を決定する。出力先は複数指定し、1つは元々接続していたポートと、もう1つは監視する側のポートを設定する。


### パッチとミラーリングポートの一覧

#### コマンド
パッチとミラーリングポートの一覧表示は下記のコマンドで行うものとする。求める一覧はスイッチ毎に定められているため、引数として与えるものは dpid のみで十分である。

> list [dpid]

このコマンドを次のファイルに記載した。該当部分をその下に示す。

* [bin/patch\_panel](https://github.com/handai-trema/patch-panel-k-sakamoto3/blob/develop/bin/patch_panel)

```ruby
  desc 'Lists patch and mirror ports'
  arg_name 'dpid li'
  command :list do |c|
    c.desc 'Location to find socket files'
    c.flag [:S, :socket_dir], default_value: Trema::DEFAULT_SOCKET_DIR

    c.action do |_global_options, options, args|
      dpid = args[0].hex
      li = Trema.trema_process('PatchPanel', options[:socket_dir]).controller.
        list_pm()
      puts "Patch list"
      li[0][dpid].each do |port_a, port_b|
        puts "host#{port_a} -- host#{port_b}"
      end
      puts "Mirror list"
      li[1][dpid].each do |port_a, port_b|
        puts "host#{port_a} -> host#{port_b}"
      end
    end
```

li = Trema...list\_pm() により、[lib/patch_panel.rb](https://github.com/handai-trema/patch-panel-k-sakamoto3/blob/develop/lib/patch_panel.rb) で定められた list\_pm を呼び出す。返り値は、1番目の要素にパッチの配列、2番目の要素にミラーポートの配列である。その後、li に格納された情報を出力する。



#### 呼び出し関数

list\_pm は次の通りである。

* [lib/patch_panel.rb](https://github.com/handai-trema/patch-panel-k-sakamoto3/blob/develop/lib/patch_panel.rb)

```ruby
  def list_pm()
    li = Array.new()
    li << @patch
    li << @mirror
    return li
  end
```

@patch には現在設定されているパッチ情報が、@mirror には現在設定されているミラーポート情報が２次元配列で格納されている。これらをさらに配列に格納しているため、li は３次元配列となる。１番目の要素が @patch を指し、２番目の要素が @mirror を指す。この li を返り値として返し、前述したコマンド実装部分で出力プログラムが実行される。


### 動作確認
最後に動作確認を行う。

#### 動作シナリオ
使用するネットワーク構成は以下の通りである。

```ruby
vswitch('patch_panel') { datapath_id 0xabc }

vhost ('host1') { ip '192.168.0.1' }
vhost ('host2') { ip '192.168.0.2' }
vhost ('host3') {
ip '192.168.0.3'
promisc true
}

link 'patch_panel', 'host1'
link 'patch_panel', 'host2'
link 'patch_panel', 'host3'
```

このネットワークに対して、次の設定・確認を行う。

1. host1 と host2 が繋ぐポートをパッチ接続する。
2. host2 が繋ぐポートを host3 が監視するようミラーポートを設定する。
3. パッチ・ミラーポートの設定状況を一覧表示する。
4. host1 と host2 の間でパケットを送出する。
5. host1, 2, 3 のパケット送受信情報を確認する。 

#### 動作結果
上記のシナリオに沿ってコマンドを押下した結果が以下の通りである。

```
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-k-sakamoto3$ ./bin/patch_panel create 0xabc 1 2
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-k-sakamoto3$ ./bin/patch_panel cmirror 0xabc 2 3
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-k-sakamoto3$ ./bin/patch_panel list 0xabc
Patch list
host1 -- host2
Mirror list
host2 -> host3
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-k-sakamoto3$ ./bin/trema send_packets --source host1 --dest host2
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-k-sakamoto3$ ./bin/trema send_packets --source host2 --dest host1
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-k-sakamoto3$ ./bin/trema show_stats host1
Packets sent:
  192.168.0.1 -> 192.168.0.2 = 1 packet
Packets received:
  192.168.0.2 -> 192.168.0.1 = 1 packet
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-k-sakamoto3$ ./bin/trema show_stats host2
Packets sent:
  192.168.0.2 -> 192.168.0.1 = 1 packet
Packets received:
  192.168.0.1 -> 192.168.0.2 = 1 packet
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-k-sakamoto3$ ./bin/trema show_stats host3
Packets received:
  192.168.0.1 -> 192.168.0.2 = 1 packet
  192.168.0.2 -> 192.168.0.1 = 1 packet
```

3~7行目でパッチリストとミラーリストが正常に表示されていることがわかる。また、最終コマンドの結果、それ以前に host3 に send\_pakects を行っていないにも関わらず、host1 と host2 の間を流れたパケットを host3 が取得できていることがわかる。これより、正常にミラーポートを設定できていることを確認した。

## プログラムに関する意見

* [lib/patch_panel.rb](https://github.com/handai-trema/patch-panel-k-sakamoto3/blob/develop/lib/patch_panel.rb)

```ruby
# (改変前)
  def start(_args)
    @patch = Hash.new { [] }
    @mirror = Hash.new { [] }
    logger.info 'PatchPanel started.'
  end
```

改変前は @patch のフォーマットは上記のようになっていた。しかし、この @patch[dpid] に、例えば [1, 2] をプッシュすると、[[1, 2]] とはならず、[1, 2] となっていた。そのため、@patch[dpid].each do |port\_a, port\_b| のような記述をすると、改変前は port_b に何も入らず、nil となっていた。今後プログラムを提供する際には、改変後のようにしておくべきだと思った。

```ruby
# (改変後)
  def start(_args)
    @patch = Hash.new { |hash, key| hash[key]=[] }
    @mirror = Hash.new { |hash, key| hash[key]=[] }
    logger.info 'PatchPanel started.'
  end
```


* [patch_panel.conf](https://github.com/handai-trema/patch-panel-k-sakamoto3/blob/develop/patch_panel.conf)

```ruby
vhost ('host3') {
ip '192.168.0.3'
promisc true
}
```

当初は host1 と host2 をパッチ接続し、host3 を host2 のミラーポートに設定した後、host1 と host2 の間に send\_packets を行っても host3 の stats に表れなかった。これは、host3 が自分宛ではないパケット情報を破棄していたからであり、conf の設定で promisc true を指定する必要があった。このような設定はあらかじめ組み込んでおくか、授業の中でご教授いただきたく思った。

## 謝辞
本課題を行うにあたって、成元くんと田中くんのレポートを参考にした。深く感謝いたします。

## 参考文献
* [Rubylife](http://www.rubylife.jp/)
