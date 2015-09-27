sub Mojo::Webqq::Message::_send_message{
    my($self,$msg) = @_;
    my $callback = sub{
        my $json = shift;
        my $status = $self->parse_send_status_msg( $json );
        if(defined $status and !$status->is_success){
            $self->debug("消息[ " .$msg->msg_id . " ]发送失败，尝试重新发送，当前TTL: " . $msg->ttl);
            $self->message_queue->put($msg);
            #$self->send_message($msg);
            return;
        }
        elsif(defined $status){
            if(ref $msg->cb eq 'CODE'){
                $msg->cb->(
                    $self,
                    $msg,     
                    $status,
                );
            }
            $self->emit(send_message =>
                $msg,
                $status
            );
        }
    };
    my $api_url = ($self->security?'https':'http') . '://d.web2.qq.com/channel/send_buddy_msg2';
    my $headers = {
        Referer => 'http://d.web2.qq.com/proxy.html?v=20130916001&callback=1&id=2',
        json    => 1,
    }; 
    use Encode;
    my @content  = map {
        if($_->{type} eq "txt"){decode "utf8",$_->{content}}
        elsif($_->{type} eq "face"){["face",0+$_->{id}]}
    } $self->face_parse($msg->content);
    #for(my $i=0;$i<@content;$i++){
    #    if(ref $content[$i] eq "ARRAY"){
    #        if(ref $content[$i] eq "ARRAY"){
    #            splice @content,$i+1,0," ";
    #        }
    #        else{
    #            $content[$i+1] = " " . $content[$i+1];
    #        }
    #    }
    #}
    my $content = [@content,["font",{name=>decode("utf8","宋体"),size=>10,style=>[0,0,0],color=>"000000"}]];
    my %s = (
        to      => $msg->receiver_id,
        face    => $self->user->face || 570,
        content => decode("utf8",$self->encode_json($content)),
        msg_id  =>  $msg->msg_id,
        clientid => $self->clientid,
        psessionid  => $self->psessionid,
    );
    $self->http_post(
        $api_url,
        $headers,
        form=>{r=>decode("utf8",$self->encode_json(\%s))},
        $callback,
    );
}
1;
