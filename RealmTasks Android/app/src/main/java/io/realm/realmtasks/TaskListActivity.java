/*
 * Copyright 2016 Realm Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package io.realm.realmtasks;

import android.content.Intent;
import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.Menu;
import android.view.MenuItem;

import java.util.HashSet;
import java.util.Iterator;
import java.util.Set;

import io.realm.Realm;
import io.realm.RealmChangeListener;
import io.realm.RealmResults;
import io.realm.realmtasks.list.ItemViewHolder;
import io.realm.realmtasks.list.TaskListAdapter;
import io.realm.realmtasks.list.TouchHelper;
import io.realm.realmtasks.model.TaskList;
import io.realm.realmtasks.model.TaskListList;
import io.realm.realmtasks.view.RecyclerViewWithEmptyViewSupport;

/**
 * Show all lists.
 */
public class TaskListActivity extends AppCompatActivity {

    private Realm realm;
    private RecyclerViewWithEmptyViewSupport recyclerView;
    private TaskListAdapter adapter;
    private TouchHelper touchHelper;
    private RealmResults<TaskListList> list;
    private boolean logoutAfterClose;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_common_list);
        recyclerView = findViewById(R.id.recycler_view);
        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        recyclerView.setEmptyView(findViewById(R.id.empty_view));
    }

    @Override
    protected void onStart() {
        super.onStart();
        if (touchHelper != null) {
            touchHelper.attachToRecyclerView(null);
        }
        adapter = null;
        realm = Realm.getDefaultInstance();
        list = realm.where(TaskListList.class).findAll();
        list.addChangeListener(new RealmChangeListener<RealmResults<TaskListList>>() {
            @Override
            public void onChange(RealmResults<TaskListList> results) {
                updateList(results);
            }
        });
        updateList(list);
    }

    private void updateList(RealmResults<TaskListList> results) {

        if (results.size() > 0 && adapter == null) {

            // The default list is being added on all devices, so according to the merge rules the default list might
            // be added multiple times. This is just a temporary fix. Proper ordered sets are being tracked here:
            // https://github.com/realm/realm-core/issues/1206
            realm.beginTransaction();
            Set<String> seen = new HashSet<>();
            Iterator<TaskList> it = results.first().getItems().iterator();
            while (it.hasNext()) {
                TaskList list = it.next();
                String id = list.getId();
                if (seen.contains(id)) {
                    it.remove();
                }
                seen.add(id);
            }
            realm.commitTransaction();

            // Create Adapter
            adapter = new TaskListAdapter(TaskListActivity.this, results.first().getItems());
            touchHelper = new TouchHelper(new Callback(), adapter);
            touchHelper.attachToRecyclerView(recyclerView);
        }
    }

    @Override
    protected void onStop() {
        list.removeAllChangeListeners();
        if (adapter != null) {
            touchHelper.attachToRecyclerView(null);
            adapter = null;
        }
        realm.removeAllChangeListeners();
        realm.close();
        realm = null;
        if (logoutAfterClose) {
            /*
             * We need call logout() here since onCreate() of the next Activity is already
             * executed before reaching here.
             */
            UserManager.logoutActiveUser();
            logoutAfterClose = false;
        }
        super.onStop();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_tasks, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch(item.getItemId()) {
            case R.id.action_add:
                if (adapter != null) {
                    adapter.onItemAdded();
                }
                return true;

            case R.id.action_logout:
                Intent intent = new Intent(TaskListActivity.this, SignInActivity.class);
                intent.setAction(SignInActivity.ACTION_IGNORE_CURRENT_USER);
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
                startActivity(intent);
                logoutAfterClose = true;
                return true;

            default:
                return super.onOptionsItemSelected(item);
        }
    }

    private class Callback implements TouchHelper.Callback {

        @Override
        public void onMoved(RecyclerView recyclerView, ItemViewHolder from, ItemViewHolder to) {
            final int fromPosition = from.getAdapterPosition();
            final int toPosition = to.getAdapterPosition();
            adapter.onItemMoved(fromPosition, toPosition);
        }

        @Override
        public void onCompleted(ItemViewHolder viewHolder) {
            adapter.onItemCompleted(viewHolder.getAdapterPosition());
        }

        @Override
        public void onDismissed(ItemViewHolder viewHolder) {
            final int position = viewHolder.getAdapterPosition();
            adapter.onItemDismissed(position);
        }

        @Override
        public boolean canDismissed() {
            return false;
        }

        @Override
        public boolean onClicked(ItemViewHolder viewHolder) {
            final int position = viewHolder.getAdapterPosition();
            final TaskList taskList = adapter.getItem(position);
            final String id = taskList.getId();
            final Intent intent = new Intent(TaskListActivity.this, TaskActivity.class);
            intent.putExtra(TaskActivity.EXTRA_LIST_ID, id);
            TaskListActivity.this.startActivity(intent);
            return true;
        }

        @Override
        public void onChanged(ItemViewHolder viewHolder) {
            adapter.onItemChanged(viewHolder);
        }

        @Override
        public void onAdded() {
            adapter.onItemAdded();
        }

        @Override
        public void onReverted(boolean shouldUpdateUI) {
            adapter.onItemReverted();
        }

        @Override
        public void onExit() {
        }
    }
}
