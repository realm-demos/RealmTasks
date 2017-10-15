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

import io.realm.Realm;
import io.realm.RealmChangeListener;
import io.realm.realmtasks.list.ItemViewHolder;
import io.realm.realmtasks.list.TaskAdapter;
import io.realm.realmtasks.list.TouchHelper;
import io.realm.realmtasks.model.TaskList;
import io.realm.realmtasks.view.RecyclerViewWithEmptyViewSupport;

/**
 * Show all tasks for a given list.
 */
public class TaskActivity extends AppCompatActivity {

    public static final String EXTRA_LIST_ID = "extra.list_id";

    private Realm realm;
    private RecyclerViewWithEmptyViewSupport recyclerView;
    private TaskAdapter adapter;
    private TouchHelper touchHelper;
    private String id;
    private TaskList taskList;
    private boolean logoutAfterClose;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_common_list);

        recyclerView = findViewById(R.id.recycler_view);
        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        recyclerView.setEmptyView(findViewById(R.id.empty_view));

        final Intent intent = getIntent();
        if (!intent.hasExtra(EXTRA_LIST_ID)) {
            throw new IllegalArgumentException(EXTRA_LIST_ID + " required");
        }
        id = intent.getStringExtra(EXTRA_LIST_ID);
    }

    @Override
    protected void onStart() {
        super.onStart();
        if (touchHelper != null) {
            touchHelper.attachToRecyclerView(null);
        }
        adapter = null;
        realm = Realm.getDefaultInstance();
        taskList = realm.where(TaskList.class).equalTo(TaskList.FIELD_ID, id).findFirstAsync();
        taskList.addChangeListener(new RealmChangeListener<TaskList>() {
            @Override
            public void onChange(TaskList taskList) {
                updateList(taskList);
            }
        });
        setTitle("Loading");
    }

    private void updateList(TaskList taskList) {
        if (taskList.isValid()) {
            setTitle(taskList.getText());
            if (adapter == null) {
                adapter = new TaskAdapter(TaskActivity.this, taskList.getItems());
                touchHelper = new TouchHelper(new Callback(), adapter);
                touchHelper.attachToRecyclerView(recyclerView);
            }
        } else {
            setTitle(getString(R.string.title_deleted));
        }
    }

    @Override
    protected void onStop() {
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
            case android.R.id.home:
                finish();
                return true;

            case R.id.action_add:
                if (adapter != null) {
                    adapter.onItemAdded();
                }
                return true;

            case R.id.action_logout:
                Intent intent = new Intent(TaskActivity.this, SignInActivity.class);
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
            return true;
        }

        @Override
        public boolean onClicked(ItemViewHolder viewHolder) {
            return false;
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
            finish();
        }
    }
}
