package extract;
use strict;
use warnings;

use base qw(Exporter);
@extract::EXPORT = qw(extract);
use File::Find::Rule;

my @ignore_props = ("box");
my @ignore_paths_android = (
    'plugins/alsa',
    'plugins/artwork-legacy',
    'plugins/cdda',
    'plugins/cocoaui',
    'plugins/converter',
    'plugins/coreaudio',
    'plugins/dca',
    'plugins/dsp_libsrc',
    'plugins/ffmpeg',
    'plugins/gtkui',
    'plugins/hotkeys',
    'plugins/mono2stereo',
    'plugins/notify',
    'plugins/nullout',
    'plugins/oss',
    'plugins/pltbrowser',
    'plugins/psf',
    'plugins/pulse',
    'plugins/rg_scanner',
    'plugins/shellexec',
    'plugins/shellexecui',
    'plugins/shn',
    'plugins/sndio',
    'plugins/soundtouch',
    'plugins/statusnotifier',
    'plugins/supereq',
    'plugins/wildmidi'
);

my @ignore_values = ('mpg123','mad');

sub extract {
    my $ddb_path = shift;
    my $android_xml = shift;
    my @lines;

    for my $f (File::Find::Rule->file()->name("*.c")->in($ddb_path)) {
        next if ($android_xml && grep ({$f =~ /\/$_\//} @ignore_paths_android));
        open F, "<$f" or die "Failed to open $f\n";
        my $relf = substr ($f, length($ddb_path)+1);
        while (<F>) {
            # configdialog
            my $line = $_;
            if (/^\s*"property\s+/) {
                my $prop;
                if (/^\s*"property\s+([a-zA-Z0-9_]+)/) {
                    $prop = $1;
                }
                elsif (/^(\s*"property\s+\\")/) {
                    my $begin = $1;
                    my $s = substr ($_, length ($begin));
                    if ($s =~ /(.*?)\\"/) {
                        $prop = $1;
                    }
                }
                if ($prop && !grep ({$_ eq $prop} @ignore_props)) {
                    if (!grep ({$_->{msgid} eq $prop} @lines)) {
                        push @lines, { f=>$relf, line=>$., msgid=>$prop };
                    }

                    # handle prop values
                    if ($line =~ /.*select\[([0-9]+)\]\s+(.*)$/) {
                        my $cnt = $1;
                        my $input = $2;
                        # get select values
                        sub next_token {
                            my $s = shift;
                            if ($$s =~ /^\s*\\"/) {
                                $$s =~ s/^\s*\\"(.*?)\\"(.*)$/$2/;
                                return $1;
                            }
                            else {
                                $$s =~ s/^\s*([\.a-zA-Z0-9_\-]+?)[ ;](.*)$/$2/;
                                return $1;
                            }
                        }
                        next_token(\$input);
                        next_token(\$input);
                        for (my $i = 0; $i < $cnt; $i++) {
                            my $val = next_token (\$input);
                            next if ($val =~ /^[0-9\.-_]*$/);
                            next if grep ({$_ eq $val} @ignore_values);
                            if (!grep ({$_->{msgid} eq $val} @lines)) {
                                print "$val\n";
                                push @lines, { f=>$relf, line=>$., msgid=>$val };
                            }
                        }
                    }
                }
            }
            elsif (/^.*DB_plugin_action_t .* {/) {
                # read until we hit title or };
                while (<F>) {
                    if (/^(\s*\.title\s*=\s*")/) {
                        my $begin = $1;
                        my $s = substr ($_, length ($begin));
                        if ($s =~ /(.*[^\\])"/) {
                            my $prop = $1;
                            if (!grep ({$_->{msgid} eq $prop} @lines)) {
                                push @lines, { f=>$relf, line=>$., msgid=>$prop };
                            }
                        }
                    }
                }
            }
        }
        close F;
    }
    return @lines;
}

1;
