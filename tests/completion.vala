/*
 Copyright (C) 2012 Christian Dywan <christian@twotoasts.de>

 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2.1 of the License, or (at your option) any later version.

 See the file COPYING for the full license text.
*/

class TestCompletion : Midori.Completion {
    public bool test_can_complete { get; set; }
    public uint test_suggestions { get; set; }

    public TestCompletion () {
    }

    public override void prepare (GLib.Object app) {
    }

    public override bool can_complete (string text) {
        return test_can_complete;
    }

    public override bool can_action (string action) {
        return false;
    }

    public override async List<Midori.Suggestion>? complete (string text, string? action, Cancellable cancellable) {
        var suggestions = new List<Midori.Suggestion> ();
        if (test_suggestions == 0)
            return null;
        if (test_suggestions >= 1)
            suggestions.append (new Midori.Suggestion (null, "First"));
        if (test_suggestions >= 2)
            suggestions.append (new Midori.Suggestion (null, "Second"));
        if (test_suggestions >= 3)
            suggestions.append (new Midori.Suggestion (null, "Third"));
        if (cancellable.is_cancelled ())
            return null;
        return suggestions;
    }
}

void completion_autocompleter () {
    var app = new Midori.App ();
    var autocompleter = new Midori.Autocompleter (app);
    assert (!autocompleter.can_complete (""));
    var completion = new TestCompletion ();
    autocompleter.add (completion);
    completion.test_can_complete = false;
    assert (!autocompleter.can_complete (""));
    completion.test_can_complete = true;
    assert (autocompleter.can_complete (""));

    completion.test_suggestions = 0;
    autocompleter.complete.begin ("");
    var loop = MainContext.default ();
    do { loop.iteration (true); } while (loop.pending ());
    assert (autocompleter.model.iter_n_children (null) == 0);

    completion.test_suggestions = 1;
    autocompleter.complete.begin ("");
    do { loop.iteration (true); } while (loop.pending ());
    assert (autocompleter.model.iter_n_children (null) == 1);

    /* Order */
    completion.test_suggestions = 2;
    autocompleter.complete.begin ("");
    do { loop.iteration (true); } while (loop.pending ());
    assert (autocompleter.model.iter_n_children (null) == 2);
    Gtk.TreeIter iter_first;
    autocompleter.model.get_iter_first (out iter_first);
    string title;
    autocompleter.model.get (iter_first, Midori.Autocompleter.Columns.MARKUP, out title);
    if (title != "First")
        error ("Expected %s but got %s", "First", title);

    /* Cancellation */
    autocompleter.complete.begin ("");
    completion.test_suggestions = 3;
    autocompleter.complete.begin ("");
    do { loop.iteration (true); } while (loop.pending ());
    int n = autocompleter.model.iter_n_children (null);
    if (n != 3)
        error ("Expected %d but got %d", 3, n);
}

struct TestCaseCompletion {
    public string prefix;
    public string text;
    public int expected_count;
}

const TestCaseCompletion[] completions = {
    { "history", "example", 1 }
};

async void complete_spec (Midori.Completion completion, TestCaseCompletion spec) {
    assert (completion.can_complete (spec.text));
    var cancellable = new Cancellable ();
    var suggestions = yield completion.complete (spec.text, null, cancellable);
    if (spec.expected_count != suggestions.length ())
        error ("%u expected for %s/ %s but got %u",
            spec.expected_count, spec.prefix, spec.text, suggestions.length ());
}

void completion_history () {
    var completion = new Midori.HistoryCompletion ();
    var app = new Midori.App ();
    var history = new Katze.Array (typeof (Katze.Item));
    app.set ("history", history);
    Sqlite.Database db;
    Sqlite.Database.open_v2 (":memory:", out db);
    db.exec ("CREATE TABLE history (uri TEXT, title TEXT);");
    db.exec ("CREATE TABLE search (uri TEXT, keywords TEXT);");
    db.exec ("CREATE TABLE bookmarks (uri TEXT, title TEXT);");
    history.set_data<unowned Sqlite.Database?> ("db", db);
    completion.prepare (app);
    foreach (var spec in completions)
        complete_spec.begin (completion, spec);
}

void main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/completion/autocompleter", completion_autocompleter);
    Test.add_func ("/completion/history", completion_history);
    Test.run ();
}

