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

package io.realm.realmtasks.list;

import android.content.Context;
import android.support.annotation.NonNull;
import android.support.v7.widget.RecyclerView;
import android.text.format.DateUtils;
import android.view.View;
import android.widget.RelativeLayout;
import android.widget.TextView;

import java.util.Date;

import io.realm.OrderedRealmCollection;
import io.realm.Realm;
import io.realm.realmtasks.model.Task;

public class TaskAdapter extends CommonAdapter<Task> implements TouchHelperAdapter {

    public TaskAdapter(Context context, OrderedRealmCollection<Task> items) {
        super(context, items);
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        super.onBindViewHolder(holder, position);
        final ItemViewHolder itemViewHolder = (ItemViewHolder) holder;
        final Task task = getItem(position);
        if (task.isValid()) {
            final TextView text = itemViewHolder.getText();
            text.setText(task.getText());

            Date taskDate = task.getDate();
            if(taskDate != null) {
                CharSequence naturalDateString = naturalDateFrom(taskDate);
                itemViewHolder.setMetadataText(naturalDateString);
            } else {
                itemViewHolder.setMetadataText(null);
            }
            narrowRightMargin(text);
            narrowRightMargin(itemViewHolder.getEditText());
            itemViewHolder.setCompleted(task.isCompleted());
        }
    }

    private CharSequence naturalDateFrom(@NonNull Date taskDueDate) {
        return DateUtils.getRelativeDateTimeString(
                context,
                taskDueDate.getTime(),
                DateUtils.DAY_IN_MILLIS,
                DateUtils.WEEK_IN_MILLIS, 0);
    }

    private void narrowRightMargin(View view) {
        final RelativeLayout.LayoutParams layoutParams = (RelativeLayout.LayoutParams) view.getLayoutParams();
        layoutParams.rightMargin = (int) (layoutParams.rightMargin * 0.2);
    }

    @Override
    public void onItemAdded() {
        final Realm realm = Realm.getDefaultInstance();
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                // TaskList might have been deleted, in that case, don't create any new.
                if (getData().isValid()) {
                    final Task task = realm.createObject(Task.class);
                    task.setText("");
                    getData().add(0, task);
                }
            }
        });
        realm.close();
    }

    @Override
    public void onItemMoved(final int fromPosition, final int toPosition) {
        final Realm realm = Realm.getDefaultInstance();
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                moveItems(fromPosition, toPosition);
            }
        });
        realm.close();
    }

    @Override
    public void onItemCompleted(final int position) {
        final Task task = getData().get(position);
        final Realm realm = Realm.getDefaultInstance();
        final int count = (int) getData().where().equalTo(Task.FIELD_COMPLETED, false).count();
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                if (!task.isCompleted()) {
                    task.setCompleted(true);
                    moveItems(position, count - 1);
                } else {
                    task.setCompleted(false);
                    moveItems(position, count);
                }
            }
        });
        realm.close();
    }

    @Override
    public void onItemDismissed(final int position) {
        final Realm realm = Realm.getDefaultInstance();
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                final Task task = getData().get(position);
                task.deleteFromRealm();
            }
        });
        realm.close();
    }

    @Override
    public void onItemReverted() {
        if (getData().size() == 0) {
            return;
        }
        final Realm realm = Realm.getDefaultInstance();
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                final Task task = getData().get(0);
                task.deleteFromRealm();
            }
        });
        realm.close();
    }

    @Override
    public int generatedRowColor(int row) {
        return ItemViewHolder.ColorHelper.getColor(ItemViewHolder.ColorHelper.taskColors, row, getItemCount());
    }

    @Override
    public void onItemChanged(final ItemViewHolder viewHolder) {
        final Realm realm = Realm.getDefaultInstance();
        final int position = viewHolder.getAdapterPosition();
        if (position < 0) {
            realm.close();
            return;
        }
        realm.executeTransaction(new Realm.Transaction() {
            @Override
            public void execute(Realm realm) {
                Task task = getData().get(position);
                task.setText(viewHolder.getText().getText().toString());
                task.setDate(null); // remove date on text change, server will set
                                    // new value if there is a value to be set.
            }
        });
        realm.close();
    }
}
