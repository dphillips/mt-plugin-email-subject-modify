package EmailSubjectModify;

use strict;

my $mt_build_email;
sub init_app {
    # Intercept the MT::build_email method to capture passed email template params
    require MT;
    no warnings 'redefine';
    unless ($mt_build_email) {
        $mt_build_email = \&MT::build_email;
        *MT::build_email = \&_build_email; 
    }
}

sub edit_template_param {
    my ( $cb, $app, $param, $tmpl ) = @_;

    # Add Email Subject field only to system email templates
    return if $app->blog;
    return unless $param->{type} eq 'email';

    my $id_map = identifier_map();

    my $tmpl_identifier = $param->{identifier};
    my $mail_id = $id_map->{$tmpl_identifier};
    my $setting = 'emailsubjmod_' . $mail_id;

    my $plugin = $cb->plugin;
    my ($subject, $hint, $hint2, $default);
    $hint2 = 'To restore default subject, erase above value then save the template.' . "<br />\n";

    if ( $tmpl_identifier eq 'new-ping' ) {
        $subject = get_setting($plugin, $setting . '-entry');
        $default = get_default_setting($plugin, $setting . '-entry');
        $hint = '[_1] Blog name [_2] Entry title' . "<br />\n";
        $hint .= $hint2 . 'Default value: ' . $default;
        $param->{email_subject_1} = $subject;
        add_subject_field($tmpl, 'email_subject_1', 'Email Subject (entry)', $hint);

        $subject = get_setting($plugin, $setting . '-category');
        $default = get_default_setting($plugin, $setting . '-category');
        $hint = '[_1] Blog name [_2] Category name' . "<br />\n";
        $hint .= $hint2 . 'Default value: ' . $default;
        $param->{email_subject_2} = $subject;
        add_subject_field($tmpl, 'email_subject_2', 'Email Subject (category)', $hint);

    } elsif ( $tmpl_identifier eq 'register_notification_email' ) {
        $subject = get_setting($plugin, $setting . '-blog');
        $default = get_default_setting($plugin, $setting . '-blog');
        $hint = '[_1] User name [_2] Blog name' . "<br />\n";
        $hint .= $hint2 . 'Default value: ' . $default;
        $param->{email_subject_1} = $subject;
        add_subject_field($tmpl, 'email_subject_1', 'Email Subject (blog)', $hint);

        $subject = get_setting($plugin, $setting . '-system');
        $default = get_default_setting($plugin, $setting . '-system');
        $hint = '[_1] User name' . "<br />\n";
        $hint .= $hint2 . 'Default value: ' . $default;
        $param->{email_subject_2} = $subject;
        add_subject_field($tmpl, 'email_subject_2', 'Email Subject (system)', $hint);

    } else {
        $subject = get_setting($plugin, $setting);
        $default = get_default_setting($plugin, $setting);

        $hint = '';
        if ( $tmpl_identifier eq 'comment_throttle' ) {
            $hint = '[_1] Blog name' . "<br />\n";
        } elsif ( $tmpl_identifier eq 'commenter_notify' ) {
            $hint = '[_1] User name [_2] Blog name' . "<br />\n";
        } elsif ( $tmpl_identifier eq 'notify-entry' ) {
            $hint = '[_1] Blog name [_2] Entry title' . "<br />\n";
        } elsif ( $tmpl_identifier eq 'new-comment' ) {
            $hint = '[_1] Blog name [_2] Entry title' . "<br />\n";
        } elsif ( $tmpl_identifier eq 'new_entry_email' ) {
            $hint = '[_1] Entry title [_2] Blog name' . "<br />\n";
        }
        $hint .= $hint2 . 'Default value: ' . $default;
        $param->{email_subject_1} = $subject;
        add_subject_field($tmpl, 'email_subject_1', 'Email Subject', $hint);
    }
}

sub CMSPostSave_template_email_subject {
    my ( $cb, $app, $obj, $original ) = @_;

    # Make sure this code is being executed only from save_template mode in CMS
    my $q = $app->param;
    return 1 unless $app->mode eq 'save';
    return 1 unless $q->param('_type') eq 'template';

    # Save Email Subject field only for system email templates
    return 1 if $app->blog;
    return 1 unless $obj->type eq 'email';

    my $plugin = $cb->plugin;
    my $id_map = identifier_map();

    my $tmpl_identifier = $obj->identifier;
    my $key = $id_map->{$tmpl_identifier};
    my $setting = 'emailsubjmod_' . $key;

    my $subject;

    if ( $tmpl_identifier eq 'new-ping' ) {
        $subject = trim($q->param('email_subject_1'));
        $plugin->set_config_value($setting . '-entry', $subject);

        $subject = trim($q->param('email_subject_2'));
        $plugin->set_config_value($setting . '-category', $subject);

    } elsif ( $tmpl_identifier eq 'register_notification_email' ) {
        $subject = trim($q->param('email_subject_1'));
        $plugin->set_config_value($setting . '-blog', $subject);

        $subject = trim($q->param('email_subject_2'));
        $plugin->set_config_value($setting . '-system', $subject);

    } else {
        $subject = $q->param('email_subject_1');
        $subject = trim($subject);
        $plugin->set_config_value($setting, $subject);
    }

    1;    
}

sub identifier_map {
    my $map = {
        # template_identifier => mail_header_id
        'comment_throttle'            => 'comment_throttle',
        'commenter_confirm'           => 'commenter_confirm',
        'email_verification_email'    => 'email_verification_email',
        'commenter_notify'            => 'commenter_notify',
        'notify-entry'                => 'notify_entry',
        'lockout-ip'                  => 'lockout_ip',
        'new-comment'                 => 'new_comment',
        'new_entry_email'             => 'entry_notification',
        'new-ping'                    => 'new_ping',
        'recover-password'            => 'recover_password',
        'verify-subscribe'            => 'verify_subscribe',
        'register_notification_email' => 'register_notification',
        'lockout-user'                => 'lockout_user',
    };
    return $map;
}

sub add_subject_field {
    my ( $tmpl, $field_id, $label, $hint ) = @_;
    
    # Add email subject field before template-body
    my $where = 'insertBefore';
    my $marker = $tmpl->getElementById('template-body');

    my $subj_field = $tmpl->createElement('app:setting', {
        id => "$field_id", 
        label => qq{<__trans phrase="$label">},
        label_class => 'top-label',
#       content_class => 'text',
        hint => $hint,
        show_hint => 1,
    });

    my $innerHTML = qq{<input type="text" name="$field_id" id="$field_id" 
       class="text" value="<mt:var name="$field_id" escape="html">" />};
    $subj_field->innerHTML($innerHTML);

    $tmpl->$where( $subj_field, $marker );
}

sub get_setting {
    my ( $plugin, $key ) = @_;

    my $setting = $plugin->get_config_value($key);
    $setting = trim($setting);

    # Load default setting if setting value is undef, blank, etc.
    $setting = get_default_setting($plugin, $key) unless $setting;

    return $setting;
}

sub get_default_setting {
    my ( $plugin, $key ) = @_;
    
    my $s = $plugin->settings;
    my $defaults = $s->defaults;

    my $app = MT->instance;
    my $default_language = $app->config->DefaultLanguage || 'en_us';
    my $current_lang = $app->current_language;

    $app->set_language($default_language);
    my $default_setting = $app->translate($defaults->{$key}, '[_1]', '[_2]');
    $app->set_language($current_lang);

    if ( $key eq 'emailsubjmod_comment_throttle' ) {
        $default_setting = '[[_1]] ' . $default_setting;
    } elsif ( $key eq 'emailsubjmod_new_comment' ) {
        $default_setting =~ s/\[_1\]/\[_2\]/;
        $default_setting = '[[_1]] ' . $default_setting;
    } elsif ( $key eq 'emailsubjmod_new_ping-entry' ) {
        $default_setting =~ s/\[_1\]/\[_2\]/;
        $default_setting = '[[_1]] ' . $default_setting;
    } elsif ( $key eq 'emailsubjmod_new_ping-category' ) {
        $default_setting =~ s/\[_1\]/\[_2\]/;
        $default_setting = '[[_1]] ' . $default_setting;
    }

    return $default_setting;
}

sub trim {
    my ($text) =  @_;
    $text = '' unless defined($text);
    # Trim leading/trailing white space
    $text =~ s/^\s+//m;
    $text =~ s/\s+$//m;
    return $text;
}

sub _build_email {
    my $class = shift;
    my ( $file, $param ) = @_;

    # Copy $param hash - changes to original $param won't affect
    # the copy before we get back to it in _modify_email_subject()
    my $param_clone;
    foreach my $var (keys(%$param)) {
        $param_clone->{$var} = $param->{$var};
    }

    # Stash $param_clone in MT::Request object so we can
    # retrieve it later (in _modify_email_subject)
    require MT::Request;
    my $r = MT::Request->instance;
    $r->cache('emailsubjmod_tmpl_params', $param_clone);

    # Call original MT::build_email
    &$mt_build_email( $class, $file, $param );
}

sub _modify_email_subject {
    my $cb = shift;
    my %args = @_;
    my $plugin = $cb->plugin;

    my $hdrs = $args{headers};
    my $subject = $hdrs->{Subject};

    my $email_id = ( exists($args{id}) ? $args{id} : undef );    

    my $id_map = identifier_map();
    my %email_id_list = map { $_ => 1 } (values %$id_map);
    return 1 unless $email_id_list{$email_id};

    require MT::Request;
    my $r = MT::Request->instance;
    my $tmpl_params = $r->cache('emailsubjmod_tmpl_params');

    my $setting = ( 'emailsubjmod_' . $email_id ) if $email_id;
    if ( $email_id eq 'new_ping' ) {
        $setting .=  '-entry'    if defined $tmpl_params->{entry};
        $setting .=  '-category' if defined $tmpl_params->{category};
    }
    if ( $email_id eq 'register_notification' ) {
        if ( defined $tmpl_params->{blog} ) {
            $setting .=  '-blog';
        } else {
            $setting .=  '-system';
        }
    }

    my $new_subject;
    $new_subject = get_setting($plugin, $setting);

    my $blog_name = $tmpl_params->{blog}->name
        if defined $tmpl_params->{blog};
    my $entry_title = $tmpl_params->{entry}->title
        if defined $tmpl_params->{entry};
    my $cat_name = $tmpl_params->{category}->label
        if defined $tmpl_params->{category};
    my $user_name = $tmpl_params->{commenter}->name
        if defined $tmpl_params->{commenter};

    if ( $email_id eq 'comment_throttle' ) {
        $new_subject =~ s/\[_1\]/$blog_name/g;

    } elsif ( $email_id eq 'commenter_notify' ) {
        $new_subject =~ s/\[_1\]/$user_name/g;
        $new_subject =~ s/\[_2\]/$blog_name/g;

    } elsif ( $email_id eq 'notify_entry' ) {
        $new_subject =~ s/\[_1\]/$blog_name/g;
        $new_subject =~ s/\[_2\]/$entry_title/g;

    } elsif ( $email_id eq 'new_comment' ) {
        $new_subject =~ s/\[_1\]/$blog_name/g;
        $new_subject =~ s/\[_2\]/$entry_title/g;

    } elsif ( $email_id eq 'entry_notification' ) {
        $new_subject =~ s/\[_1\]/$entry_title/g;
        $new_subject =~ s/\[_2\]/$blog_name/g;
        
    } elsif ( $email_id eq 'new_ping-entry' ) {
        $new_subject =~ s/\[_1\]/$blog_name/g;
        $new_subject =~ s/\[_2\]/$entry_title/g;
        
    } elsif ( $email_id eq 'new_ping-category' ) {
        $new_subject =~ s/\[_1\]/$blog_name/g;
        $new_subject =~ s/\[_2\]/$cat_name/g;

    } elsif ( $email_id eq 'register_notification' ) {
        $new_subject =~ s/\[_1\]/$user_name/g;
        $new_subject =~ s/\[_2\]/$blog_name/g;

    }

    $new_subject =~ y/\n\r/  /;
    $new_subject = process_new_subject($new_subject);
    $hdrs->{Subject} = $new_subject;

    return 1;
}

sub process_new_subject {
    my ($subj) = @_;
    require MT::I18N::default;

    my $mgr  = MT->config;
    my $mail_enc = uc( $mgr->MailEncoding || $mgr->PublishCharset );
    $mail_enc = lc $mail_enc;

    eval "require MIME::EncWords;";
    unless ($@) {
        if (   ( $mail_enc ne 'iso-8859-1' )
            || ( $subj =~ /[^[:print:]]/ ) )
        {
            $subj = MIME::EncWords::encode_mimeword(
                MT::I18N::default->encode_text_encode(
                    $subj, undef, $mail_enc
                ),
                'b',
                $mail_enc
            );
        }
    }
    else {
        $subj
            = MT::I18N::default->encode_text_encode( $subj, undef,
            $mail_enc );
    }

    return $subj;
}

1;
