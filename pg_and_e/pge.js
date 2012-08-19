var fs = require('fs');
var casper = require('casper').create();

var date = new Date(casper.cli.args[2], parseInt(casper.cli.args[3]) - 1, casper.cli.args[4]);
var count = parseInt(casper.cli.args[5]);

casper.start('https://www.pge.com/myenergyweb/appmanager/pge/customer');

casper.then(function() {
  this.echo("Filling in login form...");
  this.fill('form[name="login"]', {
    'USER': casper.cli.args[0],
    'PASSWORD': casper.cli.args[1]
  }, true);
});

casper.then(function() {
  this.echo("Logged in...");
  this.click('li#primaryNav3 a'); // myUsage
});

casper.then(function() {
  this.echo("Queuing " + count + " usage day retrievals.");
  for(var i = 0; i < count; i++) {
    var d = new Date(date.getTime() - (1000 * 60 * 60 * 24 * i));
    var url = 'https://pge.opower.com/ei/app/myEnergyUse/usage/day/' + (d.getYear()+1900) + '/' + (d.getMonth()+1) + '/' + d.getDate();
    this.echo("Queuing: " + url);
    casper.thenOpen(url, function() {
      this.echo("Fetched: " + this.getCurrentUrl());
      var data = casper.getGlobal('seriesDTO');
      if(data.sufficientData) {
        var filename = data.series[0].data[0].lowerDate + ".json";
        fs.write(filename, JSON.stringify(data), "w");
      }
    });
  }
});

casper.run();
