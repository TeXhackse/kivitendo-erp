#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# Payment module
#
#======================================================================

use SL::CP;
use SL::IS;
use SL::IR;
use strict ("vars", "subs");
#use warnings;

require "bin/mozilla/arap.pl";
require "bin/mozilla/common.pl";

our ($form, %myconfig, $lxdebug, $locale, $auth);

1;

# end of main

sub payment {
  $lxdebug->enter_sub();

  $auth->assert('cash');

  my (@curr);

  $form->{ARAP} = ($form->{type} eq 'receipt') ? "AR" : "AP";
  $form->{arap} = lc $form->{ARAP};

  # setup customer/vendor selection for open invoices
  if ($form->{all_vc}) {
    # Dieser Zweig funktioniert derzeit NIE. Ggf. ganz raus oder
    # alle offenen Zahlungen wieder korrekt anzeigen. jb 12.10.2010
    $form->all_vc(\%myconfig, $form->{vc}, $form->{ARAP});
  } else {
    CP->get_openvc(\%myconfig, \%$form);
  }

  $form->{"select$form->{vc}"} = "";

  if ($form->{"all_$form->{vc}"}) {
    # s.o. jb 12.10.2010
    $form->{"$form->{vc}_id"} = $form->{"all_$form->{vc}"}->[0]->{id};
    map { $form->{"select$form->{vc}"} .= "<option>$_->{name}--$_->{id}\n" }
      @{ $form->{"all_$form->{vc}"} };
  }

  # departments
  # auf departments kann man auch nicht mehr buchen. Raus oder wieder 
  # aktivieren? Im Backend dann auch anpassen. jb 12.10.2010
  if (@{ $form->{all_departments} || [] }) {
    $form->{selectdepartment} = "<option>\n";
    $form->{department}       = "$form->{department}--$form->{department_id}";

    map {
      $form->{selectdepartment} .=
        "<option>$_->{description}--$_->{id}\n"
    } (@{ $form->{all_departments} || [] });
  }

  CP->paymentaccounts(\%myconfig, \%$form);

  $form->{selectaccount} = "";
  $form->{"select$form->{ARAP}"} = "";

  map { $form->{selectaccount} .= "<option>$_->{accno}--$_->{description}\n" }
    @{ $form->{PR}{"$form->{ARAP}_paid"} };
  map {
    $form->{"select$form->{ARAP}"} .=
      "<option>$_->{accno}--$_->{description}\n"
  } @{ $form->{PR}{ $form->{ARAP} } };

  # currencies
  # oldcurrency ist zwar noch hier als fragment enthalten, wird aber bei
  # der aktualisierung der form auch nicht mitübernommen. das konzept
  # old_$FOO habe ich auch noch nicht verstanden ...
  # Ok. Wenn currency übernommen werden, dann in callback-string über-
  # geben und hier reinparsen, oder besser multibox oder html auslagern?
  @curr_unsorted = split(/:/, $form->{currencies});
  chomp $curr_unsorted[0];
  @curr = sort {} @curr_unsorted;
  $form->{defaultcurrency} = $form->{currency} = $form->{oldcurrency} =
    $curr[0];

  $form->{selectcurrency} = "";
  map { $form->{selectcurrency} .= "<option>$_\n" } @curr;


  &form_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub form_header {
  $lxdebug->enter_sub();

  $auth->assert('cash');

  my ($vc, $vclabel, $allvc, $arap, $department, $exchangerate);
  my ($jsscript, $button1, $button2, $onload);

  $vclabel = ucfirst $form->{vc};
  $vclabel = $locale->text($vclabel);

  if ($form->{type} eq 'receipt') {
    $form->{title}     = $locale->text('Receipt');
    $form->{origtitle} = "Receipt";
  }
  if ($form->{type} eq 'check') {
    $form->{title}     = $locale->text('Payment');
    $form->{origtitle} = "Payment";
  }

  # $locale->text('Customer')
  # $locale->text('Vendor')

  if ($form->{ $form->{vc} } eq "") {
    map { $form->{"addr$_"} = "" } (1 .. 4);
  }

  if ($form->{currency} ne $form->{defaultcurrency}) {
    $form->{exchangerate} =
      $form->format_amount(\%myconfig, $form->{exchangerate});
    if ($form->{forex}) {
      $exchangerate = qq|
              <tr>
                <th align=right nowrap>| . $locale->text('Exchangerate') . qq|</th>
                <td colspan=3><input type=hidden name=exchangerate size=10 value=$form->{exchangerate}>$form->{exchangerate}</td>
              </tr>
|;
    } else {
      $exchangerate = qq|
               <tr>
                <th align=right nowrap>| . $locale->text('Exchangerate') . qq|</th>
                <td colspan=3><input name=exchangerate size=10 value=$form->{exchangerate}></td>
              </tr>
|;
    }
  }

  foreach my $item ($form->{vc}, "account", "currency", $form->{ARAP}, "department") {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~
      s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }

  $vc =
    ($form->{"select$form->{vc}"})
    ? qq|<select name=$form->{vc}>$form->{"select$form->{vc}"}\n</select>|
    : qq|<input name=$form->{vc} size=35 value="$form->{$form->{vc}}">|;

  if ($form->{all_vc}) {
    $allvc = "checked";
    $form->{openinvoices} = "";
  } else {
    $allvc = "";
    $form->{openinvoices} = 1;
  }

  # $locale->text('AR')
  # $locale->text('AP')

  $form->{jsscript} = 1;
  $jsscript = "";
  if ($form->{jsscript}) {

    # with JavaScript Calendar
    $button1 = qq|
       <td><input name=datepaid id=datepaid size=11 title="$myconfig{dateformat}" value="$form->{datepaid}" onBlur=\"check_right_date_format(this)\">
       <input type=button name=datepaid id="trigger1" value=|
      . $locale->text('button') . qq|></td>
       |;

    #write Trigger
    $jsscript =
      Form->write_trigger(\%myconfig, "1", "datepaid", "BL", "trigger1");
  } else {

    # without JavaScript Calendar
    $button1 = qq|
                              <td><input name=transdatefrom id=transdatefrom size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\"></td>|;
  }
  $form->{javascript} .= qq|<script type="text/javascript" src="js/common.js"></script>|;
  $form->header;

  $arap = lc $form->{ARAP};
  $onload = qq|focus()|;
  $onload .= qq|;setupDateFormat('|. $myconfig{dateformat} .qq|', '|. $locale->text("Falsches Datumsformat!") .qq|')|;
  $onload .= qq|;setupPoints('|. $myconfig{numberformat} .qq|', '|. $locale->text("wrongformat") .qq|')|;
  print qq|
<body onLoad="$onload">

<form method=post action=cp.pl>

<input type=hidden name=defaultcurrency value=$form->{defaultcurrency}>
<input type=hidden name=closedto value=$form->{closedto}>
<input type=hidden name=vc value=$form->{vc}>
<input type=hidden name=type value=$form->{type}>
<input type=hidden name=formname value=$form->{type}>
<input type=hidden name=queued value="$form->{queued}">
<input type=hidden name=arap value=$arap>
<input type=hidden name=ARAP value=$form->{ARAP}>
<input type=hidden name=openinvoices value=$form->{openinvoices}>
<input type=hidden name=title value="$form->{title}">
<input type=hidden name=origtitle value="$form->{origtitle}">

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr valign=top>
          <td>
            <table>
              <tr>
                <th align=right>$vclabel</th>
                <td>$vc</td>
                <input type=hidden name="select$form->{vc}" value="| . H($form->{"select$form->{vc}"}) . qq|">
                <input type=hidden name="$form->{vc}_id" value="|    . H($form->{"$form->{vc}_id"}) . qq|">
                <input type=hidden name="old$form->{vc}" value="|    . H($form->{"old$form->{vc}"}) . qq|">
              </tr>
              <tr valign=top>
                <th align=right nowrap>| . $locale->text('Address') . qq|</th>
                <td colspan=2>
                  <table>
                    <tr>
                      <td>$form->{street}</td>
                    </tr>
                    <tr>
                      <td>$form->{zipcode}</td>
                    </tr>
                    <tr>
                      <td>$form->{city}</td>
                    </tr>
                    <tr>
                      <td>$form->{country}</td>
                    </tr>
                  </table>
                </td>
                <input type=hidden name=street value="$form->{street}">
                <input type=hidden name=zipcode value="$form->{zipcode}">
                <input type=hidden name=city value="$form->{city}">
                <input type=hidden name=country value="$form->{country}">
              </tr>
              <tr>
                <th align=right>| . $locale->text('Memo') . qq|</th>
                <td colspan=2><input name="memo" size=30 value="$form->{memo}"></td>
              </tr>
            </table>
          </td>
          <td align=right>
            <table>
              $department
              <tr>
                <th align=right nowrap>| . $locale->text('Account') . qq|</th>
                <td colspan=3><select name=account>$form->{selectaccount}</select>
                <input type=hidden name=selectaccount value="$form->{selectaccount}">
                </td>
              </tr>
              <tr>
                <th align=right nowrap>| . $locale->text('Date') . qq|</th>
                $button1
              </tr>
              <tr>
                <th align=right nowrap>| . $locale->text('Currency') . qq|</th>
                <td><select name=currency>$form->{selectcurrency}</select></td>
                <input type=hidden name=selectcurrency value="$form->{selectcurrency}">
                <input type=hidden name=oldcurrency value=$form->{oldcurrency}>
              </tr>
              $exchangerate
              <tr>
                <th align=right nowrap>| . $locale->text('Source') . qq|</th>
                <td colspan=3><input name=source value="$form->{source}" size=10></td>
              </tr>
              <tr>
                <th align="right" nowrap>| . $locale->text('Amount') . qq|</th>
                <td colspan="3">| .  $form->format_amount(\%myconfig, $form->{amount}, 2) . qq|</td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </td>
  </tr>

$jsscript
|;

  if ($form->{openinvoices_other_currencies}) {
    my $warning = $form->{vc} eq 'customer' ? $::locale->text('There are #1 more open invoices for this customer with other currencies.', $form->{openinvoices_other_currencies})
                :                             $::locale->text('There are #1 more open invoices from this vendor with other currencies.',  $form->{openinvoices_other_currencies});

    print qq|

  <input type="hidden" name="openinvoices_other_currencies" value="| . H($form->{openinvoices_other_currencies}) . qq|">
  <tr>
   <td><b>| . $::locale->text('Note') . qq|: $warning</b></td>
  </tr>
|;
  }

  $lxdebug->leave_sub();
}

sub list_invoices {
  $lxdebug->enter_sub();

  $auth->assert('cash');

  my (@column_index, %column_data, $colspan, $invoice);
  my ($totalamount, $totaldue, $totalpaid);

  @column_index = qw(invnumber transdate amount due checked paid);

  $colspan = $#column_index + 1;

  $invoice = $locale->text('Invoices');

  print qq|
  <input type=hidden name=column_index value="id @column_index">
  <tr>
    <td>
      <table width=100%>
        <tr>
          <th class=listheading colspan=$colspan>$invoice</th>
        </tr>
|;

  $column_data{invnumber} =
    qq|<th nowrap class=listheading>| . $locale->text('Invoice') . "</th>";
  $column_data{transdate} =
    qq|<th nowrap class=listheading>| . $locale->text('Date') . "</th>";
  $column_data{amount} =
    qq|<th nowrap class=listheading>| . $locale->text('Amount') . "</th>";
  $column_data{due} =
    qq|<th nowrap class=listheading>| . $locale->text('Due') . "</th>";
  $column_data{paid} =
    qq|<th nowrap class=listheading>| . $locale->text('Amount') . "</th>";
  $column_data{checked} =
    qq|<th nowrap class=listheading>| . $locale->text('Select') . "</th>";

  print qq|
        <tr>
|;
  map { print "$column_data{$_}\n" } @column_index;
  print qq|
        </tr>
|;

  for my $i (1 .. $form->{rowcount}) {

    my $j = 0;

    map {
      $form->{"${_}_$i"} =
        $form->parse_amount(\%myconfig, $form->{"${_}_$i"})
    } qw(amount due paid);

    $totalamount += $form->{"amount_$i"};
    $totaldue    += $form->{"due_$i"};
    $totalpaid   += $form->{"paid_$i"};

    map {
      $form->{"${_}_$i"} =
        $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2)
    } qw(amount due paid);

    $column_data{invnumber} = qq|<td>$form->{"invnumber_$i"}</td>
      <input type=hidden name="invnumber_$i" value="$form->{"invnumber_$i"}">
      <input type=hidden name="id_$i" value=$form->{"id_$i"}>|;
    $column_data{transdate} = qq|<td width=15%>$form->{"transdate_$i"}</td>
      <input type=hidden name="transdate_$i" value=$form->{"transdate_$i"}>|;
    $column_data{amount} =
      qq|<td align=right width=15%>$form->{"amount_$i"}</td>
      <input type=hidden name="amount_$i" value=$form->{"amount_$i"}>|;
    $column_data{due} = qq|<td align=right width=15%>$form->{"due_$i"}</td>
      <input type=hidden name="due_$i" value=$form->{"due_$i"}>|;

    $column_data{paid} =
      qq|<td align=right width=15%><input name="paid_$i" size=10 value=$form->{"paid_$i"}></td>|;

    $form->{"checked_$i"} = ($form->{"checked_$i"}) ? "checked" : "";
    $column_data{checked} =
      qq|<td align=center width=10%><input name="checked_$i" type=checkbox style=checkbox $form->{"checked_$i"}></td>|;

    $j++;
    $j %= 2;
    print qq|
        <tr class=listrow$j>
|;
    map { print "$column_data{$_}\n" } @column_index;
    print qq|
        </tr>
|;
  }

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{amount} =
      qq|<th class=listtotal align=right>|
    . $form->format_amount(\%myconfig, $totalamount, 2, "&nbsp;")
    . qq|</th>|;
  $column_data{due} =
      qq|<th class=listtotal align=right>|
    . $form->format_amount(\%myconfig, $totaldue, 2, "&nbsp;")
    . qq|</th>|;
  $column_data{paid} =
      qq|<th class=listtotal align=right>|
    . $form->format_amount(\%myconfig, $totalpaid, 2, "&nbsp;")
    . qq|</th>|;

  print qq|
        <tr class=listtotal>
|;
  map { print "$column_data{$_}\n" } @column_index;
  print qq|
        </tr>
      </table>
    </td>
  </tr>
|;

  $lxdebug->leave_sub();
}

sub form_footer {
  $lxdebug->enter_sub();

  $auth->assert('cash');

  print qq|
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
<input type=hidden name=rowcount value=$form->{rowcount}>

<br>
<input class=submit type=submit name=action value="|
    . $locale->text('Update') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('Post') . qq|">
 </form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub update {
  $lxdebug->enter_sub();

  $auth->assert('cash');

  my ($new_name_selected) = @_;

  my ($buysell, $newvc, $updated, $exchangerate, $amount);

  if ($form->{vc} eq 'customer') {
    $buysell = "buy";
  } else {
    $buysell = "sell";
  }

  # if we switched to all_vc
  # funktioniert derzeit nicht 12.10.2010 jb
  if ($form->{all_vc} ne $form->{oldall_vc}) {

    $form->{openinvoices} = ($form->{all_vc}) ? 0 : 1;

    $form->{"select$form->{vc}"} = "";

    if ($form->{all_vc}) {
      $form->all_vc(\%myconfig, $form->{vc}, $form->{ARAP});

      if ($form->{"all_$form->{vc}"}) {
        map {
          $form->{"select$form->{vc}"} .=
            "<option>$_->{name}--$_->{id}\n"
        } @{ $form->{"all_$form->{vc}"} };
      }
    } else {  # ab hier wieder ausgeführter code (s.o.):
      CP->get_openvc(\%myconfig, \%$form);

      if ($form->{"all_$form->{vc}"}) {
        $newvc =
          qq|$form->{"all_$form->{vc}"}[0]->{name}--$form->{"all_$form->{vc}"}[0]->{id}|;
        map {
          $form->{"select$form->{vc}"} .=
            "<option>$_->{name}--$_->{id}\n"
        } @{ $form->{"all_$form->{vc}"} };
      }

      # if the name is not the same
      if ($form->{"select$form->{vc}"} !~ /$form->{$form->{vc}}/) {
        $form->{ $form->{vc} } = $newvc;
      }
    }
  }

  # get customer and invoices
  $updated = &check_name($form->{vc});

  if ($new_name_selected || $updated) {
    CP->get_openinvoices(\%myconfig, \%$form);
    ($newvc) = split /--/, $form->{ $form->{vc} };
    $form->{"old$form->{vc}"} = qq|$newvc--$form->{"$form->{vc}_id"}|;
    $updated = 1;
  }

  if ($form->{currency} ne $form->{oldcurrency}) {
    $form->{oldcurrency} = $form->{currency};
    if (!$updated) {
      CP->get_openinvoices(\%myconfig, \%$form);
      $updated = 1;
    }
  }

  $form->{forex}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{datepaid}, $buysell);
  $form->{exchangerate} = $form->{forex} if $form->{forex};

  $amount = $form->{amount} = $form->parse_amount(\%myconfig, $form->{amount});

  if ($updated) {
    $form->{rowcount} = 0;

    $form->{queued} = "";

    my $i = 0;
    foreach my $ref (@{ $form->{PR} }) {
      $i++;
      $form->{"id_$i"}        = $ref->{id};
      $form->{"invnumber_$i"} = $ref->{invnumber};
      $form->{"transdate_$i"} = $ref->{transdate};
      $ref->{exchangerate} = 1 unless $ref->{exchangerate};
      $form->{"amount_$i"} = $ref->{amount} / $ref->{exchangerate};
      $form->{"due_$i"}    =
        ($ref->{amount} - $ref->{paid}) / $ref->{exchangerate};
      $form->{"checked_$i"} = "";
      $form->{"paid_$i"}    = "";

      # need to format
      map {
        $form->{"${_}_$i"} =
          $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2)
      } qw(amount due);

    }
    $form->{rowcount} = $i;
  }

  # recalculate

  # Modified from $amount = $form->{amount} by J.Zach to update amount to total
  # payment amount in Zahlungsausgang
  $amount = 0;
  for my $i (1 .. $form->{rowcount}) {

    map {
      $form->{"${_}_$i"} =
        $form->parse_amount(\%myconfig, $form->{"${_}_$i"})
    } qw(amount due paid);

    if ($form->{"checked_$i"}) {

      # calculate paid_$i
      if (!$form->{"paid_$i"}) {
        $form->{"paid_$i"} = $form->{"due_$i"};
      }

      # Modified by J.Zach, see abovev
      $amount += $form->{"paid_$i"};

    } else {
      $form->{"paid_$i"} = "";
    }

    map {
      $form->{"${_}_$i"} =
        $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2)
    } qw(amount due paid);

  }

  # Line added by J.Zach, see above
  $form->{amount}=$amount;

  &form_header;
  &list_invoices;
  &form_footer;

  $lxdebug->leave_sub();
}

sub post {
  $lxdebug->enter_sub();

  $auth->assert('cash');

  &check_form;

  if ($form->{currency} ne $form->{defaultcurrency}) {
    $form->error($locale->text('Exchangerate missing!'))
      unless $form->{exchangerate};
  }

  # Beim Aktualisieren wird das Konto übernommen
  $form->{callback} = "cp.pl?action=payment&vc=$form->{vc}&type=$form->{type}&account=$form->{account}";

  my $msg1 = "$form->{origtitle} posted!";
  my $msg2 = "Cannot post $form->{origtitle}!";

  # $locale->text('Payment posted!')
  # $locale->text('Receipt posted!')
  # $locale->text('Cannot post Payment!')
  # $locale->text('Cannot post Receipt!')
  # Die Nachrichten (Receipt posted!) werden nicht angezeigt.
  # Entweder wieder aktivieren oder komplett rausnehmen
  $form->redirect($locale->text($msg1))
    if (CP->process_payment(\%myconfig, \%$form));
  $form->error($locale->text($msg2));

  $lxdebug->leave_sub();
}

sub check_form {
  $lxdebug->enter_sub();

  $auth->assert('cash');

  my ($closedto, $datepaid, $amount);

  &check_name($form->{vc});

  if ($form->{currency} ne $form->{oldcurrency}) {
    &update;
    ::end_of_request();
  }
  $form->error($locale->text('Date missing!')) unless $form->{datepaid};
  my $selected_check = 1; 
  for my $i (1 .. $form->{rowcount}) {
    if ($form->{"checked_$i"}) {
      if ($form->parse_amount(\%myconfig, $form->{"paid_$i"}, 2) <= 0) { # negativen Betrag eingegeben
          $form->error($locale->text('Amount has to be greater then zero! Wrong row number: ') . $i);
      }
        undef($selected_check);
        # last; # ich muss doch über alle buchungen laufen, da ich noch
        # die freitext-eingabe der werte prüfen will 
    }
  }
  $form->error($locale->text('No transaction selected!')) if $selected_check;

  $closedto = $form->datetonum($form->{closedto}, \%myconfig);
  $datepaid = $form->datetonum($form->{datepaid}, \%myconfig);

  $form->error($locale->text('Cannot process payment for a closed period!'))
    if ($form->date_closed($form->{"datepaid"}, \%myconfig));

  $amount = $form->parse_amount(\%myconfig, $form->{amount});
  $form->{amount} = $amount;

  for my $i (1 .. $form->{rowcount}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      $amount -= $form->parse_amount(\%myconfig, $form->{"paid_$i"});

      push(@{ $form->{paid} },      $form->{"paid_$i"});
      push(@{ $form->{due} },       $form->{"due_$i"});
      push(@{ $form->{invnumber} }, $form->{"invnumber_$i"});
      push(@{ $form->{invdate} },   $form->{"transdate_$i"});
    }
  }

  if ($form->round_amount($amount, 2) != 0) {
    push(@{ $form->{paid} }, $form->format_amount(\%myconfig, $amount, 2));
    push(@{ $form->{due} }, $form->format_amount(\%myconfig, 0, "0"));
    push(@{ $form->{invnumber} },
         ($form->{ARAP} eq 'AR')
         ? $locale->text('Deposit')
         : $locale->text('Prepayment'));
    push(@{ $form->{invdate} }, $form->{datepaid});
  }

  $lxdebug->leave_sub();
}
