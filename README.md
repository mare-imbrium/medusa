# medusa

Just a personal project for keeping track of mum's medicines and alerting me when I have to order them.

I was earlier using a spreadsheet on Google Drive. But updating the sheet was outside my flow somehow. And it would not alert me if I was running out.

I needed something that would alert me.

And so a simple delimited file with the data in it.
And a ruby file to print out how many days I have left with each medicine, and one option for alerting me.
The alert option goes into the crontab file which will send me a mail if I need to place an order.

The file format is:

    medicine~daily~Stock~As_On
    pantocid 20~1~24~2018-03-02
    mucinac 600~1~22~2018-03-02

So as on march 2nd, I had 24 tablets of pantocid. And she takes one a day. Daily refers to how many are taken a day, and some may be 0.5 and some are 2.

The rest is calculated from this such as when do the meds finish, and how may days do we have left.


